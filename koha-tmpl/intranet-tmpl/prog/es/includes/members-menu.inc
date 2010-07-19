<!-- TMPL_IF NAME="borrowernumber" -->
<div id="menu">
<ul>	<!-- TMPL_IF NAME="circview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/circ/circulation.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Préstamo</a></li>
	<!-- TMPL_IF NAME="detailview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Detalle</a></li>
	<!-- TMPL_IF NAME="CAN_user_updatecharges" -->
	<!-- TMPL_IF NAME="finesview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/boraccount.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Multas</a></li>
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="intranetreadinghistory" --><!-- TMPL_IF NAME="readingrecordview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/readingrec.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Historial de circulación</a></li><!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_parameters"--><!-- TMPL_IF NAME="logview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/tools/viewlog.pl?do_it=1&amp;modules=MEMBERS&amp;action=MODIFY&amp;object=<!-- TMPL_VAR NAME="borrowernumber" -->">Registro de modificaciones</a></li><!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_parameters"--><!-- TMPL_IF NAME="logview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/tools/viewlog.pl?do_it=1&amp;module=MEMBERS&amp;action=MODIFY&amp;object=<!-- TMPL_VAR NAME="borrowernumber" -->">Registro de modificaciones</a></li><!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="clubs_services" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/clubs_services.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Clubs &amp; Services</a></li>

<!-- TMPL_IF NAME="EnhancedMessagingPreferences" -->
          <!-- TMPL_IF NAME="messagingview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/messaging.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Mensajeria</a></li>
        <!-- /TMPL_IF -->
</ul>
</div>
<!-- /TMPL_IF -->
