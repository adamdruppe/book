/*
	The tokens we support are:
		// comment
		"string"
		'quoted-identifier
		identifier-with-dashes-and-bangs!
		124 // number
	The special things we support are:
		if
		defun
		defmacro
		setf
		let
		progn


	A WEAKLY TYPED LANGUAGE WILL NEED A WEAKLY TYPED STRUCT IN D
*/

class Token {
}

class LeftParenthesis : Token {
	override string toString() { return "("; }
}

class RightParenthesis : Token {
	override string toString() { return ")"; }
}

class StringToken : Token {
	this(string v) { value = v; }
	string value;
	override string toString() { return value; }
}
class IdentifierToken : Token {
	this(string v) { value = v; }
	string value;
	override string toString() { return value; }
}
class QuotedIdentifierToken : Token {
	this(IdentifierToken t) { token = t; }
	IdentifierToken token;
	override string toString() { return "'" ~ token.toString(); }
}
class NumberToken : Token {
	this(string v) { value = v; }
	string value;
	override string toString() { return value; }
}

void skipComment(ref string code) {
	while(code.length && code[0] != '\n')
		code = code[1 .. $];
}

StringToken readString(ref string code) {
	assert(code[0] == '"');
	string s = code;
	int len;
	code = code[1 .. $];
	len++;
	bool escaping;
	while(code.length && !escaping && code[0] != '"') {
		// FIXME: escaping
		code = code[1 .. $];
		len++;
	}
	// pass right quote
	code = code[1 .. $];
	len++;
	return new StringToken(s[0 .. len]);
}

NumberToken readNumber(ref string code) {
	import std.ascii;
	string s = code;
	int len;
	while(code.length && isDigit(code[0])) {
		code = code[1 .. $];
		len++;
	}
	return new NumberToken(s[0 .. len]);
}

bool isValidIdentifierChar(char c) {
	return c != ' ' && c != '\n' && c != '(' && c != ')';
}

IdentifierToken readIdentifier(ref string code) {
	string s = code;
	int len;
	while(code.length && isValidIdentifierChar(code[0])) {
		code = code[1 .. $];
		len++;
	}
	return new IdentifierToken(s[0 .. len]);

}

Token[] tokenizeLisp(string code) {
	Token[] tokens;

	while(code.length) {
		switch(code[0]) {
			case ' ', '\n', '\t':
				// skip whitespace
				code = code[1 .. $];
			break;
			case '/':
				if(code.length > 1 && code[1] == '/')
					skipComment(code);
				else goto default;
			break;
			case '"':
				tokens ~= readString(code);
			break;
			case '0': .. case '9':
				tokens ~= readNumber(code);
			break;
			case '\'':
				tokens ~= new QuotedIdentifierToken(readIdentifier(code));
			break;
			case '(':
				tokens ~= new LeftParenthesis();
				code = code[1 .. $];
			break;
			case ')':
				tokens ~= new RightParenthesis();
				code = code[1 .. $];
			break;
			default:
				tokens ~= readIdentifier(code);
		}
	}

	return tokens;
}

interface Expression {
	string toD();
	Expression semantic(Context context);
	//string getAsDCode() { return null; }
}

class Atom : Expression {
	Token tok;
	this(Token t) { tok = t; }

	override string toString() {
		return tok.toString();
	}

	override string toD() { return toString(); }

	override Atom semantic(Context context) { return this; }
}

class List : Expression {
	Expression[] elements;
	this(Expression[] e) { elements = e; }

	override string toD() {
		auto code = elements[0].toD();
		code ~= "(";
		foreach(idx, e; elements[1 .. $]) {
			if(idx) code ~= ", ";
			code ~= e.toD();
		}
		code ~= ")";
		return code;
	}

	override Expression semantic(Context context) {
		if(elements.length)
		if(auto atom = cast(Atom) elements[0]) {
			if(auto i = cast(IdentifierToken) atom.tok) {
				switch(i.value) {
					case "if":
						return new If(
							elements[1],
							elements.length > 2 ? elements[2] : null,
							elements.length > 3 ? elements[3] : null)
							.semantic(context);
					case "defun":
						return new FunctionDeclaration(
							elements[1],
							elements[2],
							elements[3 .. $]);
					case "defmacro":
					case "setf":
					case "let":
					case "progn":
					default:
				}
			}
		}

		foreach(ref e; elements)
			e = e.semantic(context);
		return this;
	}
}

string getIdentifierString(Expression e) {
	if(auto atom = cast(Atom) e)
		if(auto ident = cast(IdentifierToken) atom.tok)
			return ident.value;
	assert(0);
}

class FunctionDeclaration : Expression {
	string name;
	struct Argument {
		string name;
		string type;
		Expression defaultValue;
	}
	Argument[] arguments;
	Expression[] bod;

	/*
		(defun foo (a b) ...)
		(defun foo ((a int) (b string)) ...)
	*/
	this(Expression e1, Expression e2, Expression[] e3) {
		name = getIdentifierString(e1);

		if(auto l = cast(List) e2) {
			foreach(e; l.elements) {
				if(auto atom = cast(Atom) e) {
					if(auto ident = cast(IdentifierToken) atom.tok)
						arguments ~= Argument(ident.value);
					else assert(0);
				} else if(auto list = cast(List) e) {
					Argument a;
					a.name = getIdentifierString(list.elements[0]);
					if(list.elements.length > 1)
						a.type = getIdentifierString(list.elements[1]);
					if(list.elements.length > 2)
						a.defaultValue = list.elements[2];

					arguments ~= a;
				} else assert(0);
			}
		} else assert(0);

		bod = e3;
	}

	string toD() {
		import std.string;

		string code = "auto ";
		code ~= name;
		code ~= "(";

		foreach(idx, a; arguments) {
			if(idx) code ~= ", ";
			code ~= format("T%d", idx);
			if(a.type)
				code ~= " : " ~ a.type;
		}

		code ~= ")(";
		foreach(idx, a; arguments) {
			if(idx) code ~= ", ";
			code ~= format("T%d %s", idx, a.name);
			if(a.defaultValue)
				code ~= " = " ~ a.defaultValue.toD();
		}
		code ~= ") {";
		foreach(b; bod)
			code ~= "\t" ~ b.toD() ~ ";\n";
		code ~= "}\n";
		return code;
	}

	FunctionDeclaration semantic(Context context) {
		foreach(ref a; arguments)
			if(a.defaultValue)
				a.defaultValue = a.defaultValue.semantic(context);
		foreach(ref b; bod)
			b = b.semantic(context);
		return this;
	}
}

class If : Expression {
	Expression cond;
	Expression ifTrue;
	Expression ifFalse;
	this(Expression e, Expression e1, Expression e2) {
		cond = e;
		ifTrue = e1;
		ifFalse = e2;
	}
	override string toD() {
		string code = "((";
		code ~= cond.toD();

		code ~= ") ? (";
		code ~= ifTrue.toD();
		code ~= ") : (";
		if(ifFalse !is null)
			code ~= ifFalse.toD();
		else
			code ~= "0";
		code ~= ")";

		code ~= ")";
		return code;
	}

	override If semantic(Context context) {
		cond = cond.semantic(context);
		ifTrue = ifTrue.semantic(context);
		if(ifFalse)
			ifFalse = ifFalse.semantic(context);
		return this;
	}
}

class Context {
	//Macro[string] macros;

	void registerMacro(string name, Expression[] arguments, Expression[] bod) {

	}
}

/*
class Call : Expression {
	string func;
	Expression[] args;
	this(string f, Expression[] a) { func = f; args = a; }
}
*/

Expression[] parseLisp(Token[] tokens) {
	return parseLispHelper(tokens);
}

List parseList(ref Token[] tokens) {
	assert(cast(LeftParenthesis) tokens[0]);
	tokens = tokens[1 .. $];
	auto list = new List(null);
	while(tokens.length && (cast(RightParenthesis) tokens[0]) is null) {
		list.elements ~= parseExpression(tokens);
	}
	assert(tokens.length);
	tokens = tokens[1 .. $]; // skip right parens
	return list;
}

Expression[] parseLispHelper(ref Token[] tokens) {
	Expression[] expressions;

	while(tokens.length) {
		expressions ~= parseExpression(tokens);
	}

	return expressions;
}

Expression parseExpression(ref Token[] tokens) {
	assert(tokens.length);
	Expression e;
	if(auto lp = cast(LeftParenthesis) tokens[0]) {
		e = parseList(tokens);
	} else if(auto rp = cast(RightParenthesis) tokens[0]) {
		throw new Exception("mismatched parens");
	} else {
		e = new Atom(tokens[0]);
		tokens = tokens[1 .. $];
	}
	assert(e !is null);
	return e;
}

string lispToD(string lisp) {
	auto context = new Context();
	auto es = parseLisp(tokenizeLisp(lisp));
	string D;
	foreach(e; es) {
		e = e.semantic(context);
		D ~= e.toD() ~ ";";
	}
	return D;
}

void main() {
	import std.stdio;
	auto es = parseLisp(tokenizeLisp(q{
		// this is a comment
		(writeln "Hello, world!" 12)
		(if 1 10 50)
		(defun foo (a b)
			(writeln a)
			(writeln b))
		(foo (lol 12 4) (+ 1 2))
	}));

	auto context = new Context();

	foreach(e; es) {
		e = e.semantic(context);
	//	writeln(e.toD(), ";");
	}

	// these symbols will be available to the lisp too
	int bar = 10;
	void test(T...)(T args) { writeln(args); }

	mixin(lispToD(q{
		(defun foo (a b)
			(writeln a b))
		(foo (if 1 "25" "3") "hey")
		// not implemented yet
		//(defmacro test (a b)
			//(defun a () b))
		(test bar "cool")
		(writeln (bar))
	}));
}
