<!-- TMPL_IF NAME="opacfacets" -->
<!-- TMPL_IF NAME="facets_loop" -->
<div id="search-facets">
<h4>Refine su búsqueda</h4>
<ul>
	<li>Disponibilidad<ul><li><!-- TMPL_IF NAME="available" -->Mostrando sólo <strong>disponible</strong> items. <a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR NAME="query_cgi" --><!-- TMPL_VAR NAME="limit_cgi_not_availablity" --><!-- TMPL_IF NAME="sort_by" -->&amp;sort_by=<!-- TMPL_VAR NAME="sort_by" --><!-- /TMPL_IF -->">Mostrar todos los items</a><!-- TMPL_ELSE -->Limitar a <a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR NAME="query_cgi" --><!-- TMPL_VAR NAME="limit_cgi" --><!-- TMPL_IF NAME="sort_by" -->&amp;sort_by=<!-- TMPL_VAR NAME="sort_by" --><!-- /TMPL_IF -->&amp;limit=available">items disponibles.</a><!-- /TMPL_IF --></li></ul>
	<!-- TMPL_IF NAME="related" --> <li>(búsquedas relacionadas: <!-- TMPL_LOOP NAME="related" --><!-- TMPL_VAR NAME="related_search" --><!-- /TMPL_LOOP -->)</li><!-- /TMPL_IF -->
	</li>
	
<!-- TMPL_LOOP NAME="facets_loop" -->
<li id="<!-- TMPL_VAR NAME="type_id" -->">
<!-- TMPL_IF NAME="type_label_Authors" -->Autores<!-- /TMPL_IF -->
<!-- TMPL_IF NAME="type_label_Titles" -->Títulos<!-- /TMPL_IF -->
<!-- TMPL_IF NAME="type_label_Topics" -->Temas<!-- /TMPL_IF -->
<!-- TMPL_IF NAME="type_label_Places" -->Lugares<!-- /TMPL_IF -->
<!-- TMPL_IF NAME="type_label_Series" -->Series<!-- /TMPL_IF -->
<!-- TMPL_UNLESS NAME="singleBranchMode" -->
<!-- TMPL_IF NAME="type_label_Libraries" -->Bibliotecas<!-- /TMPL_IF -->
<!-- /TMPL_UNLESS -->
<ul>
        <!-- TMPL_LOOP NAME="facets" --><li><a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR NAME="query_cgi" --><!-- TMPL_VAR NAME="limit_cgi" --><!-- TMPL_IF NAME="sort_by" -->&amp;sort_by=<!-- TMPL_VAR NAME="sort_by" --><!-- /TMPL_IF -->&amp;limit=<!-- TMPL_VAR NAME="type_link_value" -->:<!-- TMPL_VAR NAME="facet_link_value" -->" title="<!-- TMPL_VAR NAME="facet_title_value" ESCAPE="HTML" -->"><!-- TMPL_VAR NAME="facet_label_value" --></a> <!-- (<!-- TMPL_VAR NAME="facet_count" -->) --></li><!-- /TMPL_LOOP --><!-- TMPL_IF NAME="expandable" -->
        <li class="showmore"><a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR NAME="query_cgi" -->&amp;expand=<!-- TMPL_VAR NAME="expand" -->#<!-- TMPL_VAR NAME="type_id" -->">Mostrar más</a></li>
<!-- /TMPL_IF -->
</ul></li>
<!-- /TMPL_LOOP -->
</ul>
</div>
<!-- /TMPL_IF -->
<!-- /TMPL_IF -->
