<div style="margin-top: 1em;">
<h3>Configuraciones actuales</h3>
<table>
<tr><th>Diseño:</th><td><!-- TMPL_IF NAME="active_layout_name" --><!-- TMPL_VAR NAME="active_layout_name" --><!-- TMPL_ELSE --><span class="error">No se ha especificado un diseño <a href="/cgi-bin/koha/labels/label-home.pl">Seleccione una diseño de etiqueta</a></span><!-- /TMPL_IF --> </td></tr>
<tr><th>Plantilla </th><td><!-- TMPL_IF NAME="active_template_name" --><!-- TMPL_VAR NAME="active_template_name" --><!-- TMPL_ELSE --><span class="error">No se ha especificado una plantilla: <a href="/cgi-bin/koha/labels/label-templates.pl">Seleccione una plantilla de etiqueta</a></span><!-- /TMPL_IF --> </td></tr>
<tr><th>Lote: </th><td><!-- TMPL_IF NAME="batch_id" --><!-- TMPL_VAR NAME="batch_id" --><!-- TMPL_ELSE --><span class="error"><a href="/cgi-bin/koha/labels/label-manager.pl?op=add_batch&amp;type=<!-- TMPL_VAR NAME="batch_type" -->">Crear un nuevo lote</a></span><!-- /TMPL_IF --> </td></tr>
</table>
</div>
