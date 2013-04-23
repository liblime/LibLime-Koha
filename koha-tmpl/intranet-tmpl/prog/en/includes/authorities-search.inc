<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1>
<!-- Begin Authorities Resident Search Box -->
<div id="header_search" class="tabs-bottom">
    <ul>
        <li><a href="#tabs-main_heading">Search Main Heading</a></li>
        <li><a href="#tabs-all_headings">Search All Headings</a></li>
    </ul>
    <div id="tabs-main_heading" class="residentsearch">
    <p class="tip">Enter authority heading:</p>
    <form action="/cgi-bin/koha/authorities/authorities-home.pl" method="get">
        <input type="hidden" name="op" value="do_search" />
        <input type="hidden" name="type" value="intranet" />
        <select  name="authtypecode">
            <option value="">Default</option>
        <!-- TMPL_LOOP NAME="authtypesloop" -->
            <!-- TMPL_IF name="selected" -->
            <option value="<!-- TMPL_VAR NAME="value" -->" selected="selected"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- TMPL_ELSE -->
            <option value="<!-- TMPL_VAR NAME="value" -->"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- /TMPL_IF -->
        <!-- /TMPL_LOOP -->
        </select>
        <input type="hidden" name="idx" value="auth-heading" />
        <select name="operator">
            <option value="contains">contains</option>
            <option value="start">starts with</option>
            <option value="is">is exactly</option>
        </select>
        <input id="value_mainentry" type="text" name="q" value="<!-- TMPL_VAR NAME="q" -->" />
        <select name="orderby">
            <option value="auth-heading-sort asc" selected="selected">Heading A-Z</option>
            <option value="auth-heading-sort desc">Heading Z-A</option>
        </select>
        <input type="submit" class="submit" value="Submit" />
    </form>
    </div>
    <div id="tabs-all_headings" class="residentsearch">
    <p class="tip">Enter any authority field:</p>
    <form action="/cgi-bin/koha/authorities/authorities-home.pl" method="get">
        <input type="hidden" name="op" value="do_search" />
        <input type="hidden" name="type" value="intranet" />
        <select name="authtypecode">
        <!-- TMPL_LOOP NAME="authtypesloop" -->
            <!-- TMPL_IF name="selected" -->
            <option value="<!-- TMPL_VAR NAME="value" -->" selected="selected"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- TMPL_ELSE -->
            <option value="<!-- TMPL_VAR NAME="value" -->"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- /TMPL_IF -->
        <!-- /TMPL_LOOP -->
        </select>
        <input type="hidden" name="idx" value="auth-full" />
        <select name="operator">
            <option value="contains">contains</option>
            <option value="start">starts with</option>
            <option value="is">is exactly</option>
        </select>
        <input id="value_mainmainentry" type="text" name="q" value="<!-- TMPL_VAR NAME="q" -->" />
        <select name="orderby">
            <option value="auth-heading-sort asc" selected="selected">Heading A-Z</option>
            <option value="auth-heading-sort desc">Heading Z-A</option>
        </select>
        <input type="submit" class="submit" value="Submit" />
    </form>
    </div>
</div>
<!-- End Authorities Resident Search Box -->
