
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Serials Resident Search Box -->
<div id="header_search" class="tabs-bottom">
    <ul>
        <li><a href="#tabs-subscription_search">Search Periodicals</a></li>
        <!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="#tabs-circ_search">Check Out</a></li><!-- /TMPL_IF -->
        <li><a href="#tabs-catalog_search">Search the Catalog</a></li>
    </ul>
	<div id="tabs-subscription_search" class="residentsearch">
	<p class="tip">Search Subscriptions:</p>
    <form action="/cgi-bin/koha/periodicals/periodicals-home.pl" method="get">
        <label for="issn_filter">ISSN:</label> <input type="text" size="10" maxlength="11" name="issn_filter" id="issn_filter" value="<!-- TMPL_VAR name="issn_filter" -->" />
        <label for="title_filter">Title:</label>
        <input type="text" size="20" maxlength="40" name="title_filter" id="title_filter" value="<!-- TMPL_VAR name="title_filter" -->" />
        <input type="submit" value="Search" class="submit" />
    </form>
	</div>
    <!-- TMPL_INCLUDE NAME="patron-search-box.inc" -->
	<div id="tabs-catalog_search" class="residentsearch">
	<p class="tip">Enter search keywords:</p>
		<form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
			 <input type="text" name="q" id="search-form" size="40" value="" title="Enter the terms you wish to search for." class="form-text" />
				<input type="submit" value="Submit"  class="submit" />
		</form>
	</div>
</div>
<!-- End Serials Resident Search Box -->
