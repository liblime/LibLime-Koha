<!-- TMPL_IF NAME="subscriptionid" -->
<ul>
<li><a href="serials-collection.pl?subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->">Colección de publicaciones periódicas</a></li>
	<!-- TMPL_IF NAME="routing" --><li><a href="routing.pl?subscriptionid=<!-- TMPL_VAR NAME="subscriptionid" -->">Editar lista de enrutamiento</a></li><!-- TMPL_ELSE -->
	<li><a href="routing.pl?subscriptionid=<!-- TMPL_VAR NAME="subscriptionid" -->&amp;op=new">Crear lista de ruteo</a></li><!-- /TMPL_IF -->
</ul>
<!-- /TMPL_IF -->

<ul>
	<li><a href="/cgi-bin/koha/serials/claims.pl">Reclamos</a></li>
	<li><a href="/cgi-bin/koha/serials/checkexpiration.pl">Vencimiento</a></li>
</ul>