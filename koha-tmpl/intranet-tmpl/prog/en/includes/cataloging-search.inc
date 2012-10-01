
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Cataloging Resident Search Box -->
<div id="header_search" class="tabs-bottom">
    <ul>
        <li><a href="#tabs-addbooks_search">Cataloging Search</a></li>
        <!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="#tabs-circ_search">Check Out</a></li><!-- /TMPL_IF -->
    </ul>	
    <div id="tabs-addbooks_search" class="residentsearch">
    	<p class="tip">Search the catalog and the reservoir:</p>
    	<form name="search" action="addbooks.pl">
            <input type="text" name="q"  size="40" class="focus" />
            <input type="submit" class="submit" value="Submit" />
    	</form>
    </div>
    <!-- TMPL_INCLUDE NAME="patron-search-box.inc" -->
</div>
<!-- End Cataloging Resident Search Box -->
