
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Notices Resident Search Box -->
<div id="header_search">
	<div id="notices_search" class="residentsearch">
	<p class="tip">Buscar avisos existentes:</p>
<form action="/cgi-bin/koha/tools/letter.pl" method="post">
		<input type="text" name="searchfield" size="40" value="" />
                <input type="submit" class="submit" name="search" value="Buscar">
        </form>	
	</div>
    <!-- TMPL_INCLUDE NAME="patron-search-box.inc" -->
	<!-- TMPL_IF NAME="CAN_user_catalogue" -->
	<div id="catalog_search" class="residentsearch" style="display:none;">
	<p class="tip">Ingrese palabaras clave para la búsqueda:</p>
		<form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
			 <input type="text" name="q" id="search-form" size="40" value="" title="Ingrese los t&eacute;rminos de b&uacute;squeda." class="form-text">
				<input type="submit" name="op" value="Enviar" class="submit">
		</form>
	</div><!-- /TMPL_IF -->
			<ul>
			<li><a href="/cgi-bin/koha/admin/currency.pl#notices_search">Buscar avisos</a></li>
			<!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="/cgi-bin/koha/circ/circulation.pl#circ_search">Préstamo</a></li><!-- /TMPL_IF -->
			<!-- TMPL_IF NAME="CAN_user_catalogue" --><li><a href="/cgi-bin/koha/catalogue/search.pl#catalog_search">Buscar en el cat&aacute;logo</a></li><!-- /TMPL_IF -->
			</ul>	
</div>
<!-- End Notices Resident Search Box -->
