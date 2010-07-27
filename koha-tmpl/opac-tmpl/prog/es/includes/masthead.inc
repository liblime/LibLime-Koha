<div id="header-wrapper"><div id="members">
  <!-- TMPL_IF NAME="opacuserlogin" -->
	<ul><!-- TMPL_IF NAME="loggedinusername" --><li><span class="members">Bienvenido, <a href="/cgi-bin/koha/opac-user.pl"><span class="loggedinusername"><!-- TMPL_LOOP NAME="USER_INFO" --><!-- TMPL_VAR NAME="title" --> <!-- TMPL_VAR NAME="firstname" --> <!-- TMPL_VAR NAME="surname" --><!-- /TMPL_LOOP --></span></a></span></li><li><a class="logout" id="logout" href="/cgi-bin/koha/opac-main.pl?logout.x=1">Salir</a></li><!-- TMPL_ELSE --><li><a href="/cgi-bin/koha/opac-user.pl">Ingresar a su cuenta</a></li><!-- /TMPL_IF -->
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
   <!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-main.pl"><!-- TMPL_IF NAME="LibraryName" --><!-- TMPL_VAR NAME="LibraryName" --><!-- TMPL_ELSE -->Catálogo en línea Koha<!-- /TMPL_IF --></a></h1>

<div id="fluid">
<div id="fluid-offset">
<!-- TMPL_UNLESS NAME="advsearch" --><form name="searchform" method="get" action="/cgi-bin/koha/opac-search.pl" id="searchform">
    <label for="masthead_search" class="left"> Buscar <!-- TMPL_IF name="mylibraryfirst" --> (en <!-- TMPL_VAR name="mylibraryfirst" --> solamente)<!-- /TMPL_IF --></label>
	<select name="idx" id="masthead_search" class="left" style="max-width:10em;width:10em;">
	<!-- TMPL_IF NAME="ms_kw" -->
        <option selected="selected" value="">Catálogo de la biblioteca</option>
		<!-- TMPL_ELSE -->
        <option value="">Catálogo de la biblioteca</option>
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="ms_ti" -->
        <option selected="selected" value="ti">Título</option>
		<!-- TMPL_ELSE -->
        <option value="ti">Título</option>
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="ms_au" -->
        <option selected="selected" value="au">Autor</option>
		<!-- TMPL_ELSE -->
        <option value="au">Autor</option>
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="ms_su" -->
        <option selected="selected" value="su">Tema</option>
		<!-- TMPL_ELSE -->
        <option value="su">Tema</option>
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="ms_nb" -->
		<option selected="selected" value="nb">ISBN</option>
		<!-- TMPL_ELSE -->
		<option value="nb">ISBN</option>
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="ms_se" -->
        <option selected="selected" value="se">Series</option>
		<!-- TMPL_ELSE -->
        <option value="se">Series</option>
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="ms_callnum" -->
        <option selected="selected" value="callnum">Signatura topográfica</option>
		<!-- TMPL_ELSE -->
        <option value="callnum">Signatura topográfica</option>
		<!-- /TMPL_IF --></select>
<!-- TMPL_IF NAME="ms_value" -->
        <input type="text" id = "transl1" name="q" value="<!-- TMPL_VAR ESCAPE="HTML" NAME="ms_value" -->" class="left" style="width: 35%; font-size: 111%;"/><div id="translControl"></div>
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
    <input type="submit" value="Buscar" id="searchsubmit" class="left">
<!-- TMPL_IF NAME="opacbookbag" --><span id="cmspan"></span><!-- /TMPL_IF -->

<!--TMPL_IF NAME="virtualshelves" --><a href="/cgi-bin/koha/opac-shelves.pl" id="listsmenulink" class=""><i></i><span><i></i><span></span>Listas </span></a><!-- /TMPL_IF -->
    </form>
<!-- TMPL_ELSE -->
<div style="width:80%;*margin-bottom:-30px;">
<!--TMPL_IF NAME="virtualshelves" --><a href="/cgi-bin/koha/opac-shelves.pl" id="listsmenulink" class=""><i></i><span><i></i><span></span>Listas </span></a><!-- /TMPL_IF --><!-- TMPL_IF NAME="opacbookbag" --><span id="cmspan"></span><!-- /TMPL_IF -->
</div>
<!-- /TMPL_UNLESS -->

<div id="moresearches">
<a href="/cgi-bin/koha/opac-search.pl">Búsqueda avanzada</a>
<!-- TMPL_IF NAME="OpacBrowser"     --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-browser.pl">Explorar por jerarquía</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="OpacAuthorities" --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-authorities-home.pl">Exlorar por tema</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="TagsEnabled"     --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-tags.pl">Nube de etiquetas</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="OpacCloud"       --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-tags_subject.pl">Nube de temas</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="OpacTopissue"    --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-topissues.pl">Más populares</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="CourseReserves"     --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-coursereserves.pl">Course Reserves</a><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="suggestion" -->
  <!-- TMPL_IF NAME="AnonSuggestions" --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-suggestions.pl">Sugerencias de compra</a>
  <!-- TMPL_ELSIF NAME="OPACViewOthersSuggestions" --><span class="pipe"> | </span><a href="/cgi-bin/koha/opac-suggestions.pl">Sugerencias de compra</a>
  <!-- /TMPL_IF -->
<!-- /TMPL_IF -->
</div>
 </div>
</div>

<!-- TMPL_IF NAME="opacbookbag" --><div id="cartDetails">Your <TMPL_VAR NAME="opacbookbagName"> is empty.</div><!-- /TMPL_IF -->

<!-- TMPL_IF NAME="virtualshelves" -->
<div id="listsmenu" class="yuimenu" style="display: none">
    <div class="bd">
	<h4>Listas públicas</h4>
		<!-- TMPL_IF NAME="pubshelves" -->
			<ul class="first-of-type">
			<!-- TMPL_LOOP NAME="pubshelvesloop" -->
			<li class="yuimenuitem"><a href="/cgi-bin/koha/opac-shelves.pl?viewshelf=<!-- TMPL_VAR NAME="shelfnumber" -->&amp;sortfield=<!-- TMPL_VAR NAME="sortfield" -->"><!-- TMPL_VAR NAME="shelfname"  ESCAPE="html" --></a></li>
			<!-- /TMPL_LOOP -->
			</ul>   
		<!-- TMPL_ELSE -->
			No hay listas públicas
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="pubtotal" -->
			<ul class="second-of-type">
            <li class="yuimenuitem"><a class="yuimenuitemlabel" href="/cgi-bin/koha/opac-shelves.pl?display=publicshelves">Ver todas las <!--TMPL_VAR NAME="pubtotal" --> listas públicas </a></li>
			</ul>
		<!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="opacuserlogin" -->
    <!-- TMPL_IF NAME="loggedinusername" -->
<h4>Sus Listas</h4>
		<!-- TMPL_IF NAME="barshelves" -->
			<ul class="first-of-type">
			<!-- TMPL_LOOP NAME="barshelvesloop" -->
			<li class="yuimenuitem"><a href="/cgi-bin/koha/opac-shelves.pl?viewshelf=<!-- TMPL_VAR NAME="shelfnumber" -->&amp;sortfield=<!-- TMPL_VAR NAME="sortfield" -->"><!-- TMPL_VAR NAME="shelfname"  ESCAPE="html" --></a></li>
			<!-- /TMPL_LOOP -->
			</ul>   
		<!-- TMPL_ELSE -->
			No hay listas privadas
		<!-- /TMPL_IF -->
		<!-- TMPL_IF NAME="bartotal" -->
			<ul class="second-of-type">
            <li class="yuimenuitem"><a class="yuimenuitemlabel" href="/cgi-bin/koha/opac-shelves.pl?display=privateshelves">Ver todos los <!--TMPL_VAR NAME="bartotal" --> de sus listas</a></li>
			</ul>
		<!-- /TMPL_IF -->
		<ul class="second-of-type">
        <li class="yuimenuitem"><a class="yuimenuitemlabel" href="/cgi-bin/koha/opac-shelves.pl">Administrar listas</a></li>
        </ul>
    <!-- TMPL_ELSE --><ul class="first-of-type"><li><a href="/cgi-bin/koha/opac-user.pl">Ingrese a su cuenta para crear sus listas</a></li></ul>
    <!-- /TMPL_IF -->
  <!-- /TMPL_IF -->
	  </div>
</div><!-- /listmenu /virtualshelves -->
<!-- /TMPL_IF -->
<div id="listsDetails"></div>
</div>
</div>
<div id="breadcrumbs" class="yui-g">
<!-- TMPL_IF NAME="searchdesc" --><p><!-- TMPL_IF name="total" --><strong>&ldquo;<!-- TMPL_VAR NAME="query_desc" ESCAPE="HTML"--> <!-- TMPL_VAR NAME="limit_desc" ESCAPE="HTML"-->&rdquo; </strong>devolvió <!-- TMPL_VAR NAME="total" ESCAPE="HTML"--> resultados. <!-- TMPL_IF NAME="related" --> (búsquedas relacionadas: <!-- TMPL_LOOP NAME="related" --><!-- TMPL_VAR NAME="related_search" --><!-- /TMPL_LOOP -->). <!-- /TMPL_IF -->
<a href="<!-- TMPL_VAR NAME="OPACBaseURL" -->/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR name="query_cgi" ESCAPE="HTML" --><!-- TMPL_VAR NAME="limit_cgi"  ESCAPE="HTML" -->&amp;format=rss2"><img src="/opac-tmpl/prog/images/feed-icon-16x16.png" alt="Suscribirse a esta búsqueda" title="Suscribirse a esta búsqueda" border="0"></a>
<!-- TMPL_ELSE -->
<strong>No Result found!</strong>
<p>
    <!-- TMPL_IF NAME="searchdesc" -->
    Ningún resultado coincide con su búsqueda de <span style="font-weight: bold;">&ldquo;<!-- TMPL_VAR NAME="query_desc" ESCAPE="HTML" --> <!-- TMPL_VAR NAME="limit_desc" ESCAPE="HTML"-->&rdquo;</span> en Catálogo <!-- TMPL_VAR NAME="LibraryName" -->. <a href="<!-- TMPL_VAR NAME="OPACBaseURL" -->/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR name="query_cgi" ESCAPE="HTML" --><!-- TMPL_VAR NAME="limit_cgi" ESCAPE="HTML" -->&amp;format=rss2"><img src="/opac-tmpl/prog/images/feed-icon-16x16.png" alt="Suscribirse a esta búsqueda" title="Suscribirse a esta búsqueda" border="0"></a>
    <!-- TMPL_ELSE -->
    Usted no especificó ningún criterio de búsqueda.
    <!-- /TMPL_IF -->
</p>
</div>
<!-- /TMPL_IF --></p><!-- /TMPL_IF --></div>
