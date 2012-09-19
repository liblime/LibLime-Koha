<!-- TMPL_IF NAME="facets_loop" -->
<div id="search-facets">
<h4>Refine your search</h4>
<ul>
<!-- TMPL_LOOP NAME="facets_loop" -->
<li class="facet" id="<!-- TMPL_VAR NAME="field" -->_facet">
  <span class="facetDisplayName"><TMPL_VAR NAME="display"></span>
  <ul>
      <!-- TMPL_LOOP NAME="values" -->
          <li><a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR "query_uri" --><!-- TMPL_IF "sort_by" -->&amp;sort_by=<!-- TMPL_VAR "sort_by" --><!-- /TMPL_IF -->&amp;limit=<!-- TMPL_VAR "field" -->:<!-- TMPL_VAR "value" ESCAPE="HTML" -->" title="<!-- TMPL_VAR "display_value" ESCAPE="HTML" -->"><!-- TMPL_VAR "display_value" --></a> (<!-- TMPL_VAR "count" -->) </li>
      <!-- /TMPL_LOOP -->
      <!-- TMPL_IF NAME="expandable" -->
          <li class="morefacets"><a data-facet="<!-- TMPL_VAR field -->" href="/cgi-bin/koha/opac-facets.pl?<!-- TMPL_VAR NAME="query_uri" --><!-- TMPL_IF NAME="sort_by" -->&amp;sort_by=<!-- TMPL_VAR NAME="sort_by" --><!-- /TMPL_IF -->&facet=<!-- TMPL_VAR field -->">more</a></li>
      <!-- /TMPL_IF -->
  </ul>
</li>
<!-- /TMPL_LOOP -->
</ul>
</div>
<!-- /TMPL_IF -->
