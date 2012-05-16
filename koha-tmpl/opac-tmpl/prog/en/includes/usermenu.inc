<!-- TMPL_IF NAME="loggedinusername" -->
<div id="menu">
<ul>
  <!-- TMPL_IF NAME="userview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-user.pl"><div id="summarytab">my summary</div></a></li>
  <!-- TMPL_IF NAME="OPACFinesTab" -->
  <!-- TMPL_IF NAME="accountview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-account.pl"><div id="finestab">my fines</div></a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="userupdateview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-userupdate.pl"><div id="detailstab">my personal details</div></a></li>
  <!-- TMPL_IF NAME="TagsEnabled" -->
    <!-- TMPL_IF NAME="tagsview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-tags.pl"><div id="tagstab">my tags</div></a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="OpacPasswordChange" -->
    <!-- TMPL_IF NAME="passwdview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-passwd.pl"><div id="passwordtab">change my password</div></a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="opacreadinghistory" -->
  <!-- TMPL_IF NAME="readingrecview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-readingrecord.pl"><div id="readingtab">my reading history</div></a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="holdhistoryview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-holdhistory.pl"><div id="holdhisttab">my hold history</div></a></li>
  <!-- TMPL_IF name="suggestion" -->
    <!-- TMPL_UNLESS NAME="AnonSuggestions" -->
      <!-- TMPL_IF NAME="suggestionsview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-suggestions.pl"><div id="suggesttab">my purchase suggestions</div></a></li>
    <!-- /TMPL_UNLESS -->
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="EnhancedMessagingPreferences" -->
  <!-- TMPL_IF NAME="opacmsgtab" -->
    <!-- TMPL_IF NAME="messagingview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-messaging.pl"><div id="msgtab">my messaging</div></a></li>
  <!-- /TMPL_IF -->
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="virtualshelves" --> 
  <!-- TMPL_IF NAME="listsview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-shelves.pl?display=privateshelves"><div id="liststab">my lists</div></a></li>
  <!-- /TMPL_IF -->
  <!-- TMPL_IF NAME="ClubsAndServices" -->
  <!-- TMPL_IF NAME="clubs_services" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/opac-clubsAndServices.pl"><div id="clubstab">my clubs &amp; services</div></a></li>
  <!-- /TMPL_IF -->

</ul>
</div>
<!-- /TMPL_IF -->

