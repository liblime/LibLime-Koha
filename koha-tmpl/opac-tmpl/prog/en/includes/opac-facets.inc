<!-- TMPL_IF NAME="facets_loop" -->
<div id="search-facets">
<h4>Refine your search</h4>
<ul>
<!-- TMPL_LOOP NAME="facets_loop" -->
<li id="<!-- TMPL_VAR NAME="field" -->">
<TMPL_VAR NAME="display">
<ul>
        <!-- TMPL_LOOP NAME="values" --><li><a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR NAME="query_uri" --><!-- TMPL_IF NAME="sort_by" -->&amp;sort_by=<!-- TMPL_VAR NAME="sort_by" --><!-- /TMPL_IF -->&amp;limit=<!-- TMPL_VAR NAME="field" -->:<!-- TMPL_VAR NAME="value" ESCAPE="HTML" -->" title="<!-- TMPL_VAR NAME="display_value" ESCAPE="HTML" -->"><!-- TMPL_VAR NAME="display_value" --></a> (<!-- TMPL_VAR NAME="count" -->) </li><!-- /TMPL_LOOP -->
        <!-- TMPL_IF NAME="expandable" -->
        <!-- TODO: Implement popup ajax facet search -->
        <li class="showmore"><a href="/cgi-bin/koha/opac-search.pl?<!-- TMPL_VAR NAME="query_cgi" -->&amp;offset=<!-- TMPL_VAR NAME="offset" -->&amp;expand=<!-- TMPL_VAR NAME="expand" -->#<!-- TMPL_VAR NAME="type_id" -->">Show More</a></li>
<!-- /TMPL_IF -->
</ul></li>
<!-- /TMPL_LOOP -->
</ul>
</div>
<!-- /TMPL_IF -->
