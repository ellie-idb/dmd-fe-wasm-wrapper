import std.stdio;
import dmd.frontend;

void main(string[] args)
{
	import std.algorithm : each;
	writeln("Initializing dmd...");
	initDMD();
	// findImportPaths.each!addImport;
	auto t = parseModule("test.d", q{
        void foo()
        {
            foreach (i; 0..10) {}
        }
    });

	assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

	writeln("Running full semantic over file");
    t.module_.fullSemantic;
	auto generated = t.module_.prettyPrint();
	writefln("%s", generated);
}
