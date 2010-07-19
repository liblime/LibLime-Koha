<option value="relevance">Relevancia</option>
<optgroup label="Popularity"><!-- TMPL_IF NAME="popularity_dsc" -->
<option value="popularity_dsc" selected="selected">Popularidad (Mayor a Menor)</option><!-- TMPL_ELSE -->
<option value="popularity_dsc">Popularidad (Mayor a Menor)</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="popularity_asc" -->
<option value="popularity_asc" selected="selected">Popularidad (Menor a Mayor)</option><!-- TMPL_ELSE -->
<option value="popularity_asc">Popularidad (Menor a Mayor)</option><!-- /TMPL_IF -->
</optgroup>
<optgroup label="Author"><!-- TMPL_IF NAME="author_az" -->
<option value="author_az" selected="selected">Autor (A-Z)</option><!-- TMPL_ELSE -->
<option value="author_az">Autor (A-Z)</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="author_za" -->
<option value="author_za" selected="selected">Autor (Z-A)</option><!-- TMPL_ELSE -->
<option value="author_za">Autor (Z-A)</option><!-- /TMPL_IF -->
</optgroup>
<optgroup label="Call Number"><!-- TMPL_IF NAME="call_number_asc" -->
<option value="call_number_asc" selected="selected">Signatura topográfica (No-Ficción 9-0 a Ficción A-Z)</option><!-- TMPL_ELSE -->
<option value="call_number_asc">Signatura topográfica (No-Ficción 9-0 a Ficción A-Z)</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="call_number_dsc" -->
<option value="call_number_dsc" selected="selected">Signatura topográfica (Ficción Z-A a No-Ficción 9-0)</option><!-- TMPL_ELSE -->
<option value="call_number_dsc">Signatura topográfica (Ficción Z-A a No-Ficción 9-0)</option><!-- /TMPL_IF -->
</optgroup>
<optgroup label="Dates"><!-- TMPL_IF NAME="pubdate_dsc" -->
<option value="pubdate_dsc" selected="selected">Publicación/Fecha de Copyright: Nuevos a Antigüos</option><!-- TMPL_ELSE -->
<option value="pubdate_dsc">Publicación/Fecha de Copyright: Nuevos a Antigüos</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="pubdate_asc" -->
<option value="pubdate_asc" selected="selected">Publicación/Fecha de Copyright: Antigüos a Nuevos</option><!-- TMPL_ELSE -->
<option value="pubdate_asc">Publicación/Fecha de Copyright: Antigüos a Nuevos</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="acqdate_dsc" -->
<option value="acqdate_dsc" selected="selected">Fecha de adquisición: Nuevos primero</option><!-- TMPL_ELSE -->
<option value="acqdate_dsc">Fecha de adquisición: Nuevos primero</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="acqdate_asc" -->
<option value="acqdate_asc" selected="selected">Fecha de adquisición: Antiguos primero</option><!-- TMPL_ELSE -->
<option value="acqdate_asc">Fecha de adquisición: Antiguos primero</option><!-- /TMPL_IF -->
</optgroup>
<optgroup label="Title"><!-- TMPL_IF NAME="title_az" -->
<option value="title_az" selected="selected">Título (A-Z)</option><!-- TMPL_ELSE -->
<option value="title_az">Título (A-Z)</option><!-- /TMPL_IF --><!-- TMPL_IF NAME="title_za" -->
<option value="title_za" selected="selected">Título (Z-A)</option><!-- TMPL_ELSE -->
<option value="title_za">Título (Z-A)</option><!-- /TMPL_IF -->
</optgroup>

