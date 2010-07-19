<option value="relevance">Relevancia</option>

<optgroup label="Popularity">
	
	<!-- TMPL_IF NAME="popularity_dsc" -->
<option value="popularity_dsc" selected="selected">Popularidad (de mayro a menor) </option>
<!-- TMPL_ELSE -->
	<option value="popularity_dsc">Popularidad (de mayro a menor) </option>
 <!-- /TMPL_IF -->
<!-- TMPL_IF NAME="popularity_asc" -->
<option value="popularity_asc" selected="selected">Popularidad (de menor a mayor) </option>
<!-- TMPL_ELSE -->
	<option value="popularity_asc">Popularidad (de menor a mayor) </option>
 <!-- /TMPL_IF -->

</optgroup>

<optgroup label="Author">
	
	<!-- TMPL_IF NAME="author_az" -->
<option value="author_az" selected="selected">Autor (A-Z)</option>	
<!-- TMPL_ELSE -->
<option value="author_az">Autor (A-Z)</option>
 <!-- /TMPL_IF -->
<!-- TMPL_IF NAME="author_za" -->
<option value="author_za" selected="selected">Autor (Z-A)</option>
<!-- TMPL_ELSE -->
<option value="author_za">Autor (Z-A)</option>
 <!-- /TMPL_IF -->

</optgroup>

<optgroup label="Call Number">
	
	<!-- TMPL_IF NAME="call_number_asc" -->
<option value="call_number_asc" selected="selected">Signatura (No-ficción 0-9 a Ficción A-Z)</option>
<!-- TMPL_ELSE -->
	<option value="call_number_asc">Signatura (No-ficción 0-9 a Ficción A-Z)</option>
<!-- /TMPL_IF -->

<!-- TMPL_IF NAME="call_number_dsc" -->
<option value="call_number_dsc" selected="selected">Signatura (Ficción Z-A a No-ficción 9-0)</option>
<!-- TMPL_ELSE -->
	<option value="call_number_dsc">Signatura (Ficción Z-A a No-ficción 9-0)</option>
<!-- /TMPL_IF -->

</optgroup>

<optgroup label="Dates">
	<!-- TMPL_IF NAME="pubdate_dsc" -->
<option value="pubdate_dsc" selected="selected" >Fecha de publicación/Copyright: de más nuevo a más viejo</option>
	<!-- TMPL_ELSE -->
<option value="pubdate_dsc">Fecha de publicación/Copyright: de más nuevo a más viejo</option>
<!-- /TMPL_IF -->

<!-- TMPL_IF NAME="pubdate_asc" -->
<option value="pubdate_asc" selected="selected" >Fecha de publicación/Copyright: de más viejo a más nuevo</option>
<!-- TMPL_ELSE -->
<option value="pubdate_asc">Fecha de publicación/Copyright: de más viejo a más nuevo</option>
<!-- /TMPL_IF -->

<!-- TMPL_IF NAME="acqdate_dsc" -->
<option value="acqdate_dsc" selected="selected">Adquisici&oacute;n: detalle del paquete</option>
<!-- TMPL_ELSE -->
<option value="acqdate_dsc">Adquisici&oacute;n: detalle del paquete</option>
 <!-- /TMPL_IF -->

 <!-- TMPL_IF NAME="acqdate_asc" -->
<option value="acqdate_asc" selected="selected">Fecha de adquisici&oacute;n: Antiguos a Nuevos </option>
<!-- TMPL_ELSE -->
<option value="acqdate_asc">Fecha de adquisici&oacute;n: Antiguos a Nuevos </option>
 <!-- /TMPL_IF -->
</optgroup>

<optgroup label="Title">
	<!-- TMPL_IF NAME="title_az" -->
<option value="title_az" selected="selected">Título (A-Z)</option>
	<!-- TMPL_ELSE -->
<option value="title_az">Título (A-Z)</option>
	 <!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="title_za" -->
<option value="title_za" selected="selected">Título (Z-A)</option>	
	<!-- TMPL_ELSE -->
<option value="title_za">Título (Z-A)</option>
<!-- /TMPL_IF -->
</optgroup>
