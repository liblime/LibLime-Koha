<div id="toolbar">
	<script type="text/javascript">
	//<![CDATA[

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
<!--TMPL_IF Name="AddPatronLists_categorycode"-->
<!--TMPL_ELSE-->
	 	$("#addchild").parent().remove();
		$("#addprofessional").parent().remove();
		$("#addorganisation").parent().remove();
		$("#addstaff").parent().remove();
		$("#addstatistical").parent().remove();
<!--/TMPL_IF-->
	    $("#newmenuc").empty();
	    yuiToolbar();
	 });

	// YUI Toolbar Functions

	function yuiToolbar() {

		var newmenu = [
<!--TMPL_IF Name="AddPatronLists_categorycode"-->
<!--TMPL_LOOP Name="categories"-->{ text: "<!--TMPL_VAR Name="description"-->",  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;categorycode=<!--TMPL_VAR Name="categorycode"-->" },<!--/TMPL_LOOP-->
<!--TMPL_ELSE-->
			{ text: _("Usuario Adulto"),  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;category_type=A" },
			{ text: _("Socio infantil"),  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;category_type=C" },
			{ text: _("Socio profesional"),  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;category_type=P" },
			{ text: _("Organization"),  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;category_type=I" },
			{ text: _("Adminstrativo"),  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;category_type=S" },
			{ text: _("Estadístico"),  url: "/cgi-bin/koha/members/memberentry.pl?op=add&amp;category_type=X" },
<!--/TMPL_IF-->
		] 
	
    <!-- TMPL_IF NAME="CAN_user_borrowers_add_borrowers" -->
	    new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Nuevo"),
	        name: "newmenubutton",
	        menu: newmenu,
	        container: "newmenuc"
	    });
    <!-- /TMPL_IF -->
	
	}

	//]]>
	</script>
	<ul class="toolbar">
    <!-- TMPL_IF NAME="CAN_user_borrowers_add_borrowers" -->
	<li id="newmenuc">
		<form action="/cgi-bin/koha/members/memberentry.pl" method="get">
			<input type="hidden" name="op" value="add" />
			<label for="categorycode">Nuevo socio:  </label><select name="categorycode" id="categorycode">
			<!--TMPL_IF Name="AddPatronLists_categorycode"-->
				<!--TMPL_LOOP Name="categories"--><option value="<!--TMPL_VAR Name="categorycode"-->"><!--TMPL_VAR Name="description"--></option><!--/TMPL_LOOP-->
			<!-- TMPL_ELSE -->
				<option value="A">Usuario Adulto</option>
				<option value="C">Socio infantil</option>
				<option value="P">Socio profesional</option>
				<option value="I">Organization</option>
				<option value="S">Adminstrativo</option>
				<option value="X">Estadístico</option>
			<!--/TMPL_IF-->
			</select>
			<input type="submit" class="submit" value="Ir">
		</form>
	</li>
    <!-- /TMPL_IF -->
</ul>
</div>
