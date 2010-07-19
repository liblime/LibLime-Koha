<div id="menu">
<ul>
<!-- TMPL_IF NAME="Admin" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Administraci&oacute;n" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Admin">Administraci&oacute;n</a></li>
<!-- TMPL_IF NAME="Acquisitions" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Adquisiciones" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Acquisitions">Adquisiciones</a></li>
<!-- TMPL_IF NAME="Authorities" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Control de autoridades" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Authorities">Autoridades</a></li>
<!-- TMPL_IF NAME="Cataloging" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Catalogaci&oacute;n" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Cataloging">Catalogaci&oacute;n</a></li>
<!-- TMPL_IF NAME="Circulation" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Circulaci&oacute;n" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Circulation">Circulaci&oacute;n</a></li>
<!-- TMPL_IF NAME="EnhancedContent" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Configuración de contenidos mejorados" href="/cgi-bin/koha/admin/systempreferences.pl?tab=EnhancedContent">Contenido mejorado</a></li>
<!-- TMPL_IF NAME="I18N/L10N" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Internacionalización y localización" href="/cgi-bin/koha/admin/systempreferences.pl?tab=I18N/L10N">I18N/L10N</a></li>
<!-- TMPL_IF NAME="Logs" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Registros de transacción" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Logs">Logs</a></li>
<!-- TMPL_IF NAME="OAI-PMH" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="OAI-PMH " href="/cgi-bin/koha/admin/systempreferences.pl?tab=OAI-PMH">OAI-PMH </a></li>
<!-- TMPL_IF NAME="OPAC" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Acceso público del catálogo en linea" href="/cgi-bin/koha/admin/systempreferences.pl?tab=OPAC">OPAC</a></li>
<!-- TMPL_IF NAME="Patrons" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Socios" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Patrons">Socios</a></li>
<!-- TMPL_IF NAME="Searching" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Buscar" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Searching">Buscar</a></li>
<!-- TMPL_IF NAME="Serials" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Publicaciones periódicas" href="/cgi-bin/koha/admin/systempreferences.pl?tab=Serials">Publicaciones periódicas</a></li>
<!-- TMPL_IF NAME="StaffClient" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a title="Cliente administrativo" href="/cgi-bin/koha/admin/systempreferences.pl?tab=StaffClient">Cliente administrativo</a></li>
<!-- TMPL_IF NAME="" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/admin/systempreferences.pl">De uso local</a></li>
</ul>
</div>
