<div id="toolbar">
	<script type="text/javascript">
	//<![CDATA[

	 $(document).ready(function() {
	    $("#categorycode").change(function(x){
	    	window.location = '/cgi-bin/koha/members/memberentry.pl?op=add&amp;categorycode=' + $("#categorycode").val();
	    });
	 });
	//]]>
	</script>

	<ul class="toolbar">
    <!-- TMPL_IF NAME="CAN_user_borrowers_add_borrowers" -->
	<li id="newmenuc">
		<form action="/cgi-bin/koha/members/memberentry.pl" method="get">
			<input type="hidden" name="op" value="add" />
			<label for="categorycode">New Patron: </label>
	        <select id="categorycode" name="categorycode">
	        	<option value="">Select patron category</option>
	        <!-- TMPL_LOOP NAME="typeloop" -->
			<!-- TMPL_IF EXPR="typename eq 'C'" --><optgroup label="Child"><!-- /TMPL_IF -->
			<!-- TMPL_IF EXPR="typename eq 'A'" --><optgroup label="Adult"><!-- /TMPL_IF -->
			<!-- TMPL_IF EXPR="typename eq 'S'" --><optgroup label="Staff"><!-- /TMPL_IF -->
			<!-- TMPL_IF EXPR="typename eq 'I'" --><optgroup label="Organization"><!-- /TMPL_IF -->
			<!-- TMPL_IF EXPR="typename eq 'P'" --><optgroup label="Professional"><!-- /TMPL_IF -->
			<!-- TMPL_IF EXPR="typename eq 'X'" --><optgroup label="Statistical"><!-- /TMPL_IF -->
	        <!-- TMPL_LOOP NAME="categoryloop" -->
				<option value="<!-- TMPL_VAR NAME="categorycode" -->"><!-- TMPL_VAR NAME="description" --></option>
	        <!-- /TMPL_LOOP -->
	        </optgroup>
	        <!-- /TMPL_LOOP -->
			</select>

			<input type="submit" class="submit hidden" value="Go" />
		</form>
	</li>
    <!-- /TMPL_IF -->
	</ul>
</div>
