*! version 1.5
*! Doug Hemken
*! 2 February 2018

// ISSUES
// ======
// ensure infile does not have "smd" extension -- done?
// more flexible code fence --
//   respect not-dynamic code fences
//   parse info string options
// better, more extensive preamble ?
// NOGRaph option
// wrapper with dyndoc, pandoc
// rewrite in Mata

capture program drop md2dyn
program define md2dyn, rclass
	syntax anything(name=infile), [LINElength(integer 256)] ///
		[SAVing(string) replace]
	preserve
	
	local infile = ustrtrim(usubinstr(`"`infile'"', `"""', "", .))
	confirm file `"`infile'"'
	
	if ("`saving'" == "" ) {
		mata:(void)pathchangesuffix("`infile'", "smd", "saving", 0)
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
	clear
	
* Read in file
	quietly infix str doc_line 1-`linelength' using `"`infile'"'
	quietly compress doc_line
	
* Then identify code blocks
	qui generate linenum = _n
	*generate codebegin = inlist(usubstr(doc_line, 1, 7), ///
	*		"```s", "```s/", "```{s}", "```{s/}")
	qui generate codebegin = ustrregexm(doc_line, "^( ? ? ?)(```+|~~~+)\{?s(tata)?\/?(,.*)?\}?$")
	qui generate codeopts = ustrregexm(doc_line, ",") if codebegin
	qui generate noecho = ustrregexm(doc_line, "echo=FALSE") if codebegin & codeopts
	qui replace noecho = 1 if ustrregexm(doc_line, "\/") & codebegin & codeopts
	qui generate noresults = ustrregexm(doc_line, "results=FALSE") if codebegin & codeopts
	qui generate noprompt = ustrregexm(doc_line, "noprompt=TRUE") if codebegin & codeopts
	
	qui generate codefence = ustrregexm(doc_line, "^( ? ? ?)(```+|~~~+)([ ]*)$") if ~codebegin
	qui levelsof linenum if codebegin, local(cb)
	qui foreach block of local cb {
		di "begin at `block'"
		levelsof linenum if codefence & linenum > `block', local(cbe)
		local cbe : word 1 of `cbe'
		di "end at `cbe'"
		replace codebegin = -1 in `cbe'
	}
	* Replace code ```{s}
	qui expand 2 if codebegin ~= 0, generate(dup)
	qui sort linenum dup
	qui replace doc_line = "```" if codebegin==1 & dup==0
	qui replace doc_line = "<<dd_do>>" if codebegin==1 & dup==1 & codeopts==0
	qui replace doc_line = "<<dd_do: nocommands>>" if codebegin==1 & dup==1 & noecho==1
	qui replace doc_line = "<<dd_do: nooutput>>" if codebegin==1 & dup==1 & noresults==1
	qui replace doc_line = "<<dd_do: noprompt>>" if codebegin==1 & dup==1 & noprompt==1
	qui replace doc_line = "<<dd_do: quietly>>" if codebegin==1 & dup==1 & noecho==1 & noresults==1
	qui replace doc_line = "<</dd_do>>" if codebegin==-1 & dup==0
	
	qui drop dup
	qui replace linenum = _n
	
* Add graphics preamble
	expand 6 if linenum == 1, generate(duppre)
	sort linenum duppre
	by linenum duppre: generate preamble = _n
	replace doc_line = "<<dd_do: quietly>>" if linenum==1 & preamble==1
	replace doc_line = "capture graph describe Graph" if duppre==1 & preamble==1
	replace doc_line = "tempname gdate" if duppre==1 & preamble==2
	replace doc_line = `"local \`gdate' = "\`r(command_date)' \`r(command_time)'" "' if duppre==1 & preamble==3
	replace doc_line = "<</dd_do>>" if duppre==1 & preamble==4
	
	drop duppre
	replace linenum = _n

* Add new graphics links
	expand 11 if codefence==1 & doc_line=="```", generate(dupgr)
	sort linenum dupgr
	by linenum dupgr: generate graphcheck = _n
//	replace doc_line = "INSERT CODE" if codebegin==-1 & dupgr==1 & graphcheck==1
	replace doc_line = `"<<dd_do: quietly>>"' if  codebegin==-1 & dupgr==1 & graphcheck==1
	replace doc_line = `"capture graph describe Graph"' if graphcheck==2
	replace doc_line = `"local checkdate = "\`r(command_date)' \`r(command_time)'" "' if graphcheck==3
	replace doc_line = `"<</dd_do>>"' if graphcheck==4
	replace doc_line = `"<<dd_skip_if: ="\`\`gdate''"~="" & "\`\`gdate''"=="\`checkdate'">>"' if graphcheck==5
	replace doc_line = `"<<dd_graph>>"' if graphcheck==6
	replace doc_line = `"<<dd_skip_end>>"' if graphcheck==7
	replace doc_line = `"<<dd_do: quietly>>"' if graphcheck==8
	replace doc_line = `"local \`gdate' = "\`r(command_date)' \`r(command_time)'""' if graphcheck==9
	replace doc_line = `"<</dd_do>>"' if graphcheck==10
	
	drop dupgr
	replace linenum= _n 
	
* Identify display directives
	generate dispbegin = ustrregexm(doc_line, "`s") if ~codebegin
	replace doc_line = ustrregexra(doc_line, "`s", "<<dd_display: ") if dispbegin==1
	replace doc_line = ustrregexra(doc_line, "`", ">>") if dispbegin==1

* Write out the result
	quietly compress doc_line
	outfile doc_line using "`saving'", noquote wide replace
	display "  {text:Output saved as {it:`saving'}}"

* Finish up
	restore
	return local outfile "`saving'"
end
