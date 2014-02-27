<div id="toolbar">
	<script type="text/javascript">
	//<![CDATA[

     $(document).ready(function() {
        $("#toolbar select.categorycode").change(function(x){
           window.location = '/cgi-bin/koha/members/memberentry.pl?op=add&amp;categorycode=' + $("#toolbar select.categorycode").val();
        });
     });
	//]]>
	</script>

	<ul class="toolbar">
    <!-- TMPL_IF NAME="CAN_user_borrowers_add_borrowers" -->
	<li id="newmenuc">
		<form action="/cgi-bin/koha/members/memberentry.pl" method="get">
			<input type="hidden" name="op" value="add" />
			<label>New Patron: </label>
			<!-- TMPL_INCLUDE patroncat-select.inc -->
			<input type="submit" class="submit hidden" value="Go" />
		</form>
	</li>
    <!-- /TMPL_IF -->
	</ul>
</div>
