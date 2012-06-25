<!-- TMPL_LOOP pager --><div class="pages">
    <!-- TMPL_IF NAME="has_previous" --><a class="nav" href="<!-- TMPL_VAR NAME="url" -->&amp;<!-- TMPL_VAR offset_param -->=<!-- TMPL_VAR NAME="previous_page_offset" -->">&lt;&lt; Previous</a><!-- /TMPL_IF -->
    <!-- TMPL_LOOP NAME="page_numbers" --><!-- TMPL_IF NAME="current_page" --><span class="current"><!-- TMPL_VAR NAME="pg" --></span><!-- TMPL_ELSE --><a class="nav" href="<!-- TMPL_VAR NAME="url" -->&amp;<!-- TMPL_VAR offset_param -->=<!-- TMPL_VAR NAME="pg_offset" -->"><!-- TMPL_VAR NAME="pg" --></a><!-- /TMPL_IF -->
    <!-- /TMPL_LOOP -->
    <!-- TMPL_IF NAME="next_page_offset" --><a class="nav" href="<!-- TMPL_VAR NAME="url" -->&amp;<!-- TMPL_VAR offset_param -->=<!-- TMPL_VAR NAME="next_page_offset" -->">Next &gt;&gt;</a><!-- /TMPL_IF -->
</div><!-- /TMPL_LOOP -->
