*! version 1.0
*! Doug Hemken
*! 16 March 2018

capture program drop md2html
program define md2html, rclass
	syntax anything(name=infile)    /// input file name
		[, SAVing(string) replace]  //  name of HTML file
display `"`infile'"'
	* infile checks	
	local infile = ustrtrim(usubinstr(`"`infile'"', `"""', "", .))
	confirm file `"`infile'"'
	
	* outfile checks
	if ("`saving'" == "" ) {
		mata:(void)pathchangesuffix("`infile'", "html", "saving", 0)
		}
	mata: (void)pathresolve("`c(pwd)'", `"`saving'"', "saving")
	local issame = 0
	mata: (void)filesarethesame("`infile'", "`saving'", "issame")
	if ("`issame'" == "1") {
display in error "target file can not be the same as the source file"
		exit 602			
	}
	if ("`replace'"=="") {
		confirm new file "`saving'"
		}

	* intermediate dyndoc file
	tempfile dyn
	* process
	md2dyn `infile', saving(`dyn') `replace'
	dyndoc `dyn', saving(`saving') `replace'
	
end
