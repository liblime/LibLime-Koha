<script type="text/javascript">//<![CDATA[
	$(document).ready(function() {
		var path = location.pathname.substring(1);
		$('#navmenulist a[href$="/' + path + '"]').css('font-weight','bold');
	});
//]]>
</script>
<div id="navmenu"><ul id="navmenulist">
	<li><a href="/cgi-bin/koha/tools/tools-home.pl">Herramientas</a></li>
    <!-- TMPL_IF NAME="CAN_user_tools_edit_news" -->
	<li><a href="/cgi-bin/koha/tools/koha-news.pl">Noticias</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_label_creator" -->
	<li><a href="/cgi-bin/koha/labels/label-home.pl">Etiquetas (columna vertebral y de código de barras)</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_edit_calendar" -->
	<li><a href="/cgi-bin/koha/tools/holidays.pl">Calendario</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_edit_notices" -->
	<li><a href="/cgi-bin/koha/tools/letter.pl">Avisos</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_edit_notice_status_triggers" -->
	<li><a href="/cgi-bin/koha/tools/overduerules.pl">Disparadores de aviso/estado</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_moderate_comments" -->
	<li><a href="/cgi-bin/koha/reviews/reviewswaiting.pl">Moderar OPAC comentarios</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_moderate_comments" --><!-- FIXME: Update here when Tag specific permission is created. --><li><a href="/cgi-bin/koha/tags/review.pl">Moderar pestañas de socio</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_view_system_logs" -->
	<li><a href="/cgi-bin/koha/tools/viewlog.pl">Visor del log</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_inventory" -->
	<li><a href="/cgi-bin/koha/tools/inventory.pl">Inventario/existencias</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_batch_edit_items" -->
	<li><a href="/cgi-bin/koha/tools/batchitemedit.pl">Batch Item Edit</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_stage_marc_import" -->
	<li><a href="/cgi-bin/koha/tools/stage-marc-import.pl">MARC Importación (preparados)</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_manage_staged_marc" -->
	<li><a href="/cgi-bin/koha/tools/manage-marc-import.pl">Importación MARC (gestión de lotes)</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_export_catalog" -->
	<li><a href="/cgi-bin/koha/tools/export.pl">Exportar registros bibliográficos/existencias</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_import_patrons" -->
	<li><a href="/cgi-bin/koha/tools/import_borrowers.pl">Importar socios</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_delete_anonymize_patrons" -->
	<li><a href="/cgi-bin/koha/tools/cleanborrowers.pl">Socios (anonimizar, borrar en bloque)</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_batch_upload_patron_images" -->
	<li><a href="/cgi-bin/koha/tools/picture-upload.pl">Subir imágenes de socios</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_tools_schedule_tasks" -->
	<li><a href="/cgi-bin/koha/tools/scheduler.pl">Planificador de Tareas</a></li>
    <!-- /TMPL_IF -->
</ul></div>
