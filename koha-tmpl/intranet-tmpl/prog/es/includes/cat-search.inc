
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Catalogue Resident Search Box -->
<div id="header_search">
<!-- TMPL_INCLUDE NAME="patron-search-box.inc" -->	
<!-- TMPL_IF NAME="CAN_user_circulate" -->
<div id="checkin_search" class="residentsearch" style="display:none;">
    <p class="tip">Ingrese código de barras para devolución:</p>
    <form method="post" action="/cgi-bin/koha/circ/returns.pl">
        <input name="barcode" id="ret_barcode" size="40" />
        <input value="Enviar" class="submit" type="submit">
    </form>
</div>
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_catalogue" -->
	<div id="catalog_search" class="residentsearch">
	<p class="tip">Ingrese palabaras clave para la búsqueda:</p>
		<form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
			 <input type="text" name="q" id="search-form" size="40" value="" title="Ingrese los t&eacute;rminos de b&uacute;squeda." class="form-text">
				<input type="submit" class="submit" value="Enviar">
		</form>
	</div>
	<!-- /TMPL_IF -->
	
			<ul>
			<!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="/cgi-bin/koha/circ/circulation.pl#circ_search">Préstamo</a></li><!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="/cgi-bin/koha/circ/returns.pl#checkin_search">Devolución</a></li><!-- /TMPL_IF -->
			<!-- TMPL_IF NAME="CAN_user_catalogue" --><li class="ui-tabs-selected"><a href="/cgi-bin/koha/catalogue/search.pl#catalog_search">Buscar en el cat&aacute;logo</a></li><!-- /TMPL_IF -->
			</ul>	
</div>
<!-- End Catalogue Resident Search Box -->
