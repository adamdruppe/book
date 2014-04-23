string lispToD(string lisp, string file = __FILE__, size_t line = __LINE__) {
	string code;
	while(lisp.length) {
		code ~= lispToDHelper(lisp, file, line);
		code ~= ";";
	}
	return code;
}
string lispToDHelper(ref string lisp, string file, ref size_t line) {
	import std.conv;
	string code;

	/*
		Our language will be simplified: it only has
		parens, identifiers, strings, and numbers.
	*/
	while(lisp.length && (lisp[0] == ' ' || lisp[0] == '\t'))
		// skip leading whitespace
		lisp = lisp[1 .. $];
	if(lisp.length)
	switch(lisp[0]) {
		case '\n':
			line++;
			code = "\n#line " ~ to!string(line) ~ "\n";
			lisp = lisp[1 .. $];
		break;
		case '(':
			// functions
			lisp = lisp[1 .. $];
			if(lisp.length == 0)
				throw new Exception("Unmatched paren", file, line);

			string[] args;
			while(lisp.length && lisp[0] != ')') {
				args ~= lispToDHelper(lisp, file, line);
			}
			if(lisp.length == 0)
				throw new Exception("Unclosed paren", file, line);
			lisp = lisp[1 .. $];
			if(args.length) {
				switch(args[0]) {
					// infix operators
					case "+", "-", "*", "/", "%", "~":
						code ~= "(";
						if(args.length > 2) {
							code ~= args[1];
							code ~= args[0];
							code ~= args[2];
						} else if(args.length > 1) {
							code ~= args[0];
							code ~= args[1];
						}
						code ~= ")";
					break;
					default:
						code ~= args[0];
						code ~= "(";
						foreach(i, arg; args[1 .. $]) {
							if(i)
								code ~= ", ";
							code ~= arg;
						}
						code ~= ")";
				}

			}
		break;
		case ')':
			assert(0);
		break;
		case '"':
			// strings
			if(lisp.length == 1)
				throw new Exception("Unclosed quote", file, line);
			int endingIndex = 1;
			bool isEscaping;
			while(endingIndex < lisp.length &&
				!isEscaping &&
				lisp[endingIndex] != '"')
			{
				if(isEscaping)
					isEscaping = false;
				else if(lisp[endingIndex] == '\\')
					isEscaping = true;

				endingIndex++;
			}
			endingIndex++; // the end quote
			code = lisp[0 .. endingIndex];
			lisp = lisp[endingIndex .. $];

		break;
		case '0':
		..
		case '9':
			// numbers
			int endingIndex = 0;
			while(endingIndex < lisp.length &&
				lisp[endingIndex] >= '0' &&
				lisp[endingIndex] <= '9')
			{
				endingIndex++;
			}
			code = lisp[0 .. endingIndex];
			lisp = lisp[endingIndex .. $];
		break;
		default:
			// anything else is an identifier
			int endingIndex = 0;
			while(endingIndex < lisp.length &&
				lisp[endingIndex] != ' ' &&
				lisp[endingIndex] != ')')
			{
				endingIndex++;
			}
			code = lisp[0 .. endingIndex];
			lisp = lisp[endingIndex .. $];
	}

	return code;
}

void foo(string[] a...) {
	import std.stdio;
	writeln(a);
}

string bar(int a) {
	import std.conv;
	return to!string(a);
}

void main() {
	import std.conv;
	import std.stdio;
	int a = 3;
	mixin(lispToD(q{
		(foo "lol")
		(foo (to!string (* 12 (+ 6 6))))
		(foo (bar 12) "giggle" (bar (+ 5 25)))
		(writeln (+ 5 a))
	}));
		//(baz)
}
