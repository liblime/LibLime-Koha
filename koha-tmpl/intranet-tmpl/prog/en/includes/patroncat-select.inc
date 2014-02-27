
<select name="categorycode" class="categorycode">
	<option value="">Select patron category</option>
    <!-- TMPL_LOOP NAME="typeloop" -->
	<!-- TMPL_IF EXPR="typename eq 'C'" --><optgroup label="Child"><!-- /TMPL_IF -->
	<!-- TMPL_IF EXPR="typename eq 'A'" --><optgroup label="Adult"><!-- /TMPL_IF -->
	<!-- TMPL_IF EXPR="typename eq 'S'" --><optgroup label="Staff"><!-- /TMPL_IF -->
	<!-- TMPL_IF EXPR="typename eq 'I'" --><optgroup label="Organization"><!-- /TMPL_IF -->
	<!-- TMPL_IF EXPR="typename eq 'P'" --><optgroup label="Professional"><!-- /TMPL_IF -->
	<!-- TMPL_IF EXPR="typename eq 'X'" --><optgroup label="Statistical"><!-- /TMPL_IF -->
	    <!-- TMPL_LOOP NAME="categoryloop" -->
	    	<!-- TMPL_IF selected -->
				<option value="<!-- TMPL_VAR NAME="categorycode" -->" selected="selected"><!-- TMPL_VAR NAME="description" --></option>
			<!-- TMPL_ELSE -->
				<option value="<!-- TMPL_VAR NAME="categorycode" -->"><!-- TMPL_VAR NAME="description" --></option>
			<!-- /TMPL_IF -->
	    <!-- /TMPL_LOOP -->
    </optgroup>
    <!-- /TMPL_LOOP -->
</select>
