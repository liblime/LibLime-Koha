<!-- TMPL_IF ms_idx -->
<script>
    $(document).ready(function(){
        $("#masthead_search").val('<!-- TMPL_VAR ms_idx ESCAPE="JS" -->');
    });
</script>
<!-- /TMPL_IF -->
<div id="header-wrapper"><div id="members">
  <!-- TMPL_IF NAME="opacuserlogin" -->
	<ul><!-- TMPL_IF NAME="loggedinusername" --><li><span class="members">Welcome, <a href="/cgi-bin/koha/opac-user.pl"><span class="loggedinusername"><!-- TMPL_LOOP NAME="USER_INFO" --><!-- TMPL_VAR NAME="title" --> <!-- TMPL_VAR NAME="firstname" --> <!-- TMPL_VAR NAME="surname" --><!-- /TMPL_LOOP --></span></a></span></li><li><a class="logout" id="logout" href="/cgi-bin/koha/opac-main.pl?logout.x=1">Log Out</a></li><!-- TMPL_ELSE --><li><a href="/cgi-bin/koha/opac-user.pl">Log in to Your Account</a></li><!-- /TMPL_IF -->
	</ul>	
  <!-- /TMPL_IF -->
</div>
  <!-- TMPL_IF NAME="opacheader" -->
	<!-- TMPL_VAR NAME="opacheader" -->
  <!-- /TMPL_IF -->
<div id="opac-main-search" class="yui-g">
   <!-- TMPL_IF NAME="opacsmallimage" -->
   <h1 id="libraryname" style="background-image: url('<!-- TMPL_VAR NAME="opacsmallimage" -->');">
   <!-- TMPL_ELSE -->
   <h1 id="libraryname">
   <!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-main.pl"><!-- TMPL_IF NAME="LibraryName" --><!-- TMPL_VAR NAME="LibraryName" --><!-- TMPL_ELSE -->Koha Online Catalog<!-- /TMPL_IF --></a></h1>

<div id="fluid">
<div id="fluid-offset">
<!-- TMPL_UNLESS NAME="advsearch" --><form name="searchform" method="get" action="/cgi-bin/koha/opac-search.pl" id="searchform">
    <label for="masthead_search" class="left"> Search <!-- TMPL_IF name="mylibraryfirst" --> (in <!-- TMPL_VAR name="mylibraryfirst" --> only)<!-- /TMPL_IF --></label>
	<select name="idx" id="masthead_search" class="left" style="max-width:10em;width:10em;">
        <option value="">Library Catalog</option>
        <option value="title">Title</option>
        <option value="author">Author</option>
        <option value="subject">Subject</option>
        <option value="isbn">ISBN</option>
        <option value="series-title">Series</option>
        <option value="callnumber">Call Number</option>
    </select>
        <!-- TMPL_IF NAME="OPACQuickSearchFilter" -->
        <select name="limit" class="left">
          <!-- TMPL_LOOP NAME="OPACQuickSearchFilter" -->
          <!-- TMPL_IF NAME="separator" -->
          <option disabled="disabled" class="separator">------</option>
          <!-- TMPL_ELSE -->
          <option value="<!-- TMPL_VAR NAME="value" -->"><!-- TMPL_VAR NAME="label" --></option>
          <!-- /TMPL_IF -->
          <!-- /TMPL_LOOP -->
        </select>
        <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="searchdomainoptions" -->
    <div id="searchcategories_masthead">
      <select name="multibranchlimit" class="left">
        <option value="">All libraries</option>
        <!-- TMPL_LOOP NAME="searchdomainoptions" -->
        <option value="<TMPL_VAR NAME="categorycode">" <TMPL_IF NAME="selected">selected="selected"</TMPL_IF>><TMPL_VAR NAME="categoryname"></option>
        <!-- /TMPL_LOOP -->
      </select>
    </div>
    <!-- /TMPL_IF --> <!-- NAME="searchdomainoptions" -->

<!-- TMPL_IF NAME="ms_query" -->
        <input type="text" id = "transl1" name="q" value="<!-- TMPL_VAR ESCAPE="HTML" NAME="ms_query" -->" class="left" style="width: 35%; font-size: 111%;"/><div id="translControl"></div>
<!-- TMPL_ELSE -->
        <input type="text" id = "transl1" name="q" class="left" style="width: 35%; font-size: 111%;"/><div id="translControl"></div>
<!-- /TMPL_IF -->
   <!-- TMPL_UNLESS NAME="opac_limit_override" -->
       <!-- TMPL_IF name="mylibraryfirst" --> 
            <input name="limit" value="branch:<!-- TMPL_VAR name="mylibraryfirst" -->" type="hidden" />
       <!-- /TMPL_IF -->
    <!-- /TMPL_UNLESS -->
    <!-- TMPL_IF NAME="opac_search_limit" -->
        <input name="limit" value="<!-- TMPL_VAR name="opac_search_limit" -->" type="hidden" />
    <!-- /TMPL_IF -->
    <input type="submit" value="Go" id="searchsubmit" class="left" />
<!-- TMPL_IF NAME="opacbookbag" --><span id="cmspan"></span><!-- /TMPL_IF -->

<!--TMPL_IF NAME="virtualshelves" --><a href="/cgi-bin/koha/opac-shelves.pl" id="listsmenulink" class=""><i></i><span><i></i><span></span>Lists </span></a><!-- /TMPL_IF -->
    </form>
<!-- TMPL_ELSE -->
<div style="width:80%;*margin-bottom:-30px;">
<!--TMPL_IF NAME="virtualshelves" --><a href="/cgi-bin/koha/opac-shelves.pl" id="listsmenulink" class=""><i></i><span><i></i><span></span>Lists </span></a><!-- /TMPL_IF --><!-- TMPL_IF NAME="opacbookbag" --><span id="cmspan"></span><!-- /TMPL_IF -->
</div>
<!-- /TMPL_UNLESS -->

<div id="moresearches">
<a href="/cgi-bin/koha/opac-search.pl">Advanced Search</a>
<!-- TMPL_IF NAME="OpacBrowser"     --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-browser.pl">Browse by Hierarchy</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="OpacAuthorities" --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-authorities-home.pl">Browse by Subject</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="TagsEnabled"     --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-tags.pl">Tag Cloud</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="OpacCloud"       --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-tags_subject.pl">Subject Cloud</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="OpacTopissue"    --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-topissues.pl">Most Popular</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="NewTitlesAge"    --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-search.pl?q=*&limit=catdate:[NOW-<!-- TMPL_VAR NewTitlesAge -->DAYS%20TO%20*]&sort=catdate%20desc" title="Show all titles added to the catalog in the last <!-- TMPL_VAR NewTitlesAge --> days">New Titles</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="CourseReserves"     --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-coursereserves.pl">Course Reserves</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="suggestion" -->
  <!-- TMPL_IF NAME="AnonSuggestions" --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-suggestions.pl">Purchase Suggestions</a>
  <!-- TMPL_ELSIF NAME="OPACViewOthersSuggestions" --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-suggestions.pl">Purchase Suggestions</a>
  <!-- /TMPL_IF -->
<!-- /TMPL_IF -->
</div>
 </div>
</div>

<!-- TMPL_IF NAME="opacbookbag" --><div id="cartDetails">Your <TMPL_VAR NAME="opacbookbagName"> is empty.</div><!-- /TMPL_IF -->

<!-- TMPL_IF NAME="virtualshelves" -->
<div id="listsmenu" class="yuimenu" style="display: none">
    <div class="bd">
	<h4>Public Lists</h4>
		<!-- TMPL_IF NAME="pubshelves" -->
			<ul class="first-of-type">
			<!-- TMPL_LOOP NAME="pubshelvesloop" -->
			<li class="yuimenuitem"><a href="/cgi-bin/koha/opac-shelves.pl?viewshelf=<!-- TMPL_VAR NAME="shelfnumber" -->&amp;sortfield=<!-- TMPL_VAR NAME="sortfield" -->"><!-- TMPL_VAR NAME="shelfname"  ESCAPE="html" --></a></li>
			<!-- /TMPL_LOOP -->
			</ul>   
		<!-- TMPL_ELSE -->
			No Public Lists
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="pubtotal" -->
			<ul class="second-of-type">
            <li class="yuimenuitem"><a class="yuimenuitemlabel" href="/cgi-bin/koha/opac-shelves.pl?display=publicshelves">View all <!--TMPL_VAR NAME="pubtotal" --> public lists</a></li>
			</ul>
		<!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="opacuserlogin" -->
    <!-- TMPL_IF NAME="loggedinusername" -->
<h4>Your Lists</h4>
		<!-- TMPL_IF NAME="barshelves" -->
			<ul class="first-of-type">
			<!-- TMPL_LOOP NAME="barshelvesloop" -->
			<li class="yuimenuitem"><a href="/cgi-bin/koha/opac-shelves.pl?viewshelf=<!-- TMPL_VAR NAME="shelfnumber" -->&amp;sortfield=<!-- TMPL_VAR NAME="sortfield" -->"><!-- TMPL_VAR NAME="shelfname"  ESCAPE="html" --></a></li>
			<!-- /TMPL_LOOP -->
			</ul>   
		<!-- TMPL_ELSE -->
			No Private Lists
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="bartotal" -->
			<ul class="second-of-type">
            <li class="yuimenuitem"><a class="yuimenuitemlabel" href="/cgi-bin/koha/opac-shelves.pl?display=privateshelves">View all <!--TMPL_VAR NAME="bartotal" --> of your lists</a></li>
			</ul>
		<!-- /TMPL_IF -->
		<ul class="second-of-type">
        <li class="yuimenuitem"><a class="yuimenuitemlabel" href="/cgi-bin/koha/opac-shelves.pl">Manage Lists</a></li>
        </ul>
    <!-- TMPL_ELSE --><ul class="first-of-type"><li><a href="/cgi-bin/koha/opac-user.pl">Log in to Create Your Own Lists</a></li></ul>
    <!-- /TMPL_IF -->
  <!-- /TMPL_IF -->
	  </div>
</div><!-- /listmenu /virtualshelves -->
<!-- /TMPL_IF -->
<div id="listsDetails"></div>
</div>
</div>
<div id="breadcrumbs" class="yui-g">
<!-- TMPL_IF NAME="searchdesc" --><div id="search_desc">
    <span class="search_desc">Your search:</span> <ul><li class="searchTerm">&ldquo;<!-- TMPL_VAR NAME="user_query" ESCAPE="HTML"-->&rdquo;</li></ul>
    <!-- TMPL_IF "user_limit" --><span class="search_desc">Limited to:</span> <ul><!-- TMPL_LOOP user_limit --><li class="limit"><!-- TMPL_VAR "limit_desc" ESCAPE="HTML"--></li><!-- /TMPL_LOOP --> </ul><!-- /TMPL_IF -->
    <p class="resultscount">Returned <span class="numresults"><!-- TMPL_VAR NAME="total" --></span> results.
    <span class="rssfeed"><a href="<!-- TMPL_VAR NAME="OPACBaseURL" -->/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR name="user_query" -->&amp;format=rss2"><img src="/opac-tmpl/prog/images/feed-icon-16x16.png" alt="Subscribe to this search" title="Subscribe to this search" border="0" /></a></span></p>
    </div>
<!-- TMPL_ELSE -->
  <!-- TMPL_UNLESS search_form -->
    <!-- <p>You did not specify any search criteria. </p> -->
  <!-- /TMPL_UNLESS -->
<!-- /TMPL_IF -->
</div>
<!-- /TMPL_IF --></p><!-- /TMPL_IF --></div>
