<!-- TMPL_IF NAME="loggedinusername" -->
<div id="menu">
<ul>
  <!-- TMPL_IF NAME="userview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-user.pl">mi resumen</a></li>
  <!-- TMPL_IF NAME="OPACFinesTab" -->
  <!-- TMPL_IF NAME="accountview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-account.pl">mis multas</a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="userupdateview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-userupdate.pl">mis detalles personales</a></li>
  <!-- TMPL_IF NAME="TagsEnabled" -->
    <!-- TMPL_IF NAME="tagsview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-tags.pl">mis etiquetas</a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="OpacPasswordChange" -->
    <!-- TMPL_IF NAME="passwdview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-passwd.pl">cambiar mi contraseña</a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="opacreadinghistory" -->
  <!-- TMPL_IF NAME="readingrecview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-readingrecord.pl">mi historial de lecturas</a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF name="suggestion" -->
    <!-- TMPL_UNLESS NAME="AnonSuggestions" -->
      <!-- TMPL_IF NAME="suggestionsview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-suggestions.pl">mis sugerencias de compra</a></li>
    <!-- /TMPL_UNLESS -->
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="EnhancedMessagingPreferences" -->
  <!-- TMPL_IF NAME="opacmsgtab" -->
    <!-- TMPL_IF NAME="messagingview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-messaging.pl">mi mensajería</a></li>
  <!-- /TMPL_IF -->
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="virtualshelves" --> 
  <!-- TMPL_IF NAME="listsview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-shelves.pl?display=privateshelves">mis listas</a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="clubs_services" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-clubsAndServices.pl">my clubs &amp; services</a></li>

</ul>
</div>
<!-- /TMPL_IF -->

