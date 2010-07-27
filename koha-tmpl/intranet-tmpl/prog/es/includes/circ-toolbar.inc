<div id="toolbar">
	<script type="text/javascript">
	//<![CDATA[

function confirm_deletion() {
    var is_confirmed = window.confirm(_('Are you sure you want to delete this patron? This cannot be undone.'));
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/deletemem.pl?member=<!-- TMPL_VAR NAME="borrowernumber" -->';
    }
}

function confirm_updatechild() {
    var is_confirmed = window.confirm(_('Are you sure you want to update this child to an Adult category?  This cannot be undone.'));
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/update-child.pl?op=update&borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&catcode=<!-- TMPL_VAR NAME="catcode" -->&catcode_multi=<!-- TMPL_VAR NAME="CATCODE_MULTI" -->';
    }
}

function confirm_reregistration() {
    var is_confirmed = window.confirm(_('Are you sure you want to renew this patron\'s registration?'));
    // var borrowernumbervalue1 = $("#borrowernumber").attr("value");
    if (is_confirmed) {
	window.location = '/cgi-bin/koha/members/setstatus.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;cardnumber=<!-- TMPL_VAR NAME="cardnumber" -->&amp;destination=circ&amp;reregistration=y';
    }
}

function update_child() {
    // var borrowernumbervalue= $("#borrowernumber").attr("value"); 
<!-- TMPL_IF NAME="CATCODE_MULTI" -->
 window.open('/cgi-bin/koha/members/update-child.pl?op=multi&borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->','UpdateChild','width=400,height=300,toolbar=no,scrollbars=no,resizable=yes');
<!-- TMPL_ELSE -->
 confirm_updatechild();
<!-- /TMPL_IF -->
}

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
	    $("#printslip").parent().remove();
		$("#patronflags").parent().remove();
		$("#deletepatron").parent().remove();
		$("#moremenuc").empty();
	    $("#printmenuc").empty();
	    yuiToolbar();
	 });

	// YUI Toolbar Functions
	function printx_window(print_type) {
		window.open("/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;print=" + print_type, "printwindow");
		return false;
	}

	function yuiToolbar() {
	    var printmenu = [
	        { text: _("Imprimir página"), onclick: {fn: function(){printx_window("page")}} },
	        { text: _("Imprimir tira"), onclick: {fn: function(){printx_window("slip")}} },
	        { text: _("Quick Slip"), onclick: {fn: function(){printx_window("qslip")}} }
	    ];
	
		var moremenu = [
            <!-- TMPL_IF NAME="CAN_user_circulate_renew_expired" -->
			{ text: _("Renovar socio"),  onclick: { fn: confirm_reregistration } },
            <!-- /TMPL_IF -->
            { text: _("Establecer permisos"), url: "/cgi-bin/koha/members/member-flags.pl?member=<!-- TMPL_VAR NAME="borrowernumber" -->"
                <!-- TMPL_IF NAME="CAN_user_permissions" --><!-- TMPL_IF NAME="StaffMember" -->
                    <!-- TMPL_UNLESS NAME="CAN_user_staffaccess" -->, disabled: true<!-- /TMPL_UNLESS-->
                    <!-- TMPL_ELSE --><!-- /TMPL_IF -->
                <!-- TMPL_ELSE -->, disabled: true<!-- /TMPL_IF-->},
            <!-- TMPL_IF NAME="CAN_user_borrowers_delete_borrowers" --> 
            { text: _("Borrar"), <!-- TMPL_IF NAME="StaffMember" --><!-- TMPL_UNLESS NAME="CAN_user_staffaccess" -->disabled: true, <!-- /TMPL_UNLESS --><!-- /TMPL_IF --> onclick: { fn: confirm_deletion } },
            <!-- /TMPL_IF -->
                        { text: _("Copy Patron"), url: "/cgi-bin/koha/members/memberentry.pl?op=add&borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&category_type=<!-- TMPL_VAR NAME="category_type" -->&categorycode=<!-- TMPL_VAR NAME="categorycode" -->&copy=1"},
			{ text: _("Actualizar usuario niño a adulto") , onclick: { fn: update_child }<!-- TMPL_UNLESS NAME="is_child" -->, disabled: true<!-- /TMPL_UNLESS -->}
		];

	    new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Imprimir"),
	        name: "printmenubutton",
	        menu: printmenu,
	        container: "printmenuc"
	    });   
	
	    new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Mas"),
	        name: "moremenubutton",
	        menu: moremenu,
	        container: "moremenuc"
	    });
	
	    <!-- TMPL_IF name="adultborrower" -->new YAHOO.widget.Button("addchild");<!-- /TMPL_IF -->
	    new YAHOO.widget.Button("editpatron");
	    new YAHOO.widget.Button("addnote");
        <!-- TMPL_IF NAME="StaffMember" --><!-- TMPL_IF NAME="CAN_user_staffaccess" --> new YAHOO.widget.Button("changepassword");  <!-- /TMPL_IF-->
            <!-- TMPL_ELSE--> new YAHOO.widget.Button("changepassword"); <!-- /TMPL_IF -->
	    new YAHOO.widget.Button("printslip");
		new YAHOO.widget.Button("printpage");
<!-- TMPL_IF NAME="CAN_user_circulate_renew_expired" -->
	    new YAHOO.widget.Button("renewpatron");		 
<!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="CAN_user_permissions" -->
          <!-- TMPL_IF NAME="StaffMember" -->
            <!-- TMPL_IF NAME="CAN_user_staffaccess" -->
              new YAHOO.widget.Button("patronflags");
            <!-- /TMPL_IF -->
          <!-- TMPL_ELSE-->
          new YAHOO.widget.Button("patronflags");
          <!-- /TMPL_IF -->
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="StaffMember" --><!-- TMPL_UNLESS NAME="CAN_user_staffaccess" -->new YAHOO.widget.Button("deletepatron");<!-- /TMPL_UNLESS -->
            <!-- TMPL_ELSE -->new YAHOO.widget.Button("deletepatron");<!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="show_override" -->new YAHOO.widget.Button("override_login");<!-- /TMPL_IF -->
	}

	//]]>
	</script>
	<ul class="toolbar">
	<!-- TMPL_IF NAME="CAN_user_borrowers" -->
    <!-- TMPL_IF name="CAN_user_borrowers_edit_borrowers" -->
	<!-- TMPL_IF NAME="category_type" -->
            <!--TMPL_IF NAME="guarantor"-->
                <li><a id="editpatron" href="/cgi-bin/koha/members/memberentry.pl?op=modify&amp;destination=circ&amp;borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;guarantorid=<!-- TMPL_VAR NAME="guarantorborrowernumber" -->&amp;category_type=<!-- TMPL_VAR NAME="category_type"-->">
            <!--TMPL_ELSE-->
            <li><a id="editpatron" href="/cgi-bin/koha/members/memberentry.pl?op=modify&amp;destination=circ&amp;borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;category_type=<!-- TMPL_VAR NAME="category_type"-->">
            <!--/TMPL_IF-->Editar</a></li>
        <!-- TMPL_ELSE --> <!-- try with categorycode if no category_type -->
            <!-- TMPL_IF NAME="categorycode" -->
            <li><a id="editpatron" href="/cgi-bin/koha/members/memberentry.pl?op=modify&amp;destination=circ&amp;borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;categorycode=<!-- TMPL_VAR NAME="categorycode"-->">Editar</a></li>
            <!-- TMPL_ELSE --> <!-- if no categorycode, set category_type to A by default -->
                <li><a id="editpatron" href="/cgi-bin/koha/members/memberentry.pl?op=modify&amp;destination=circ&amp;borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;category_type=A">Editar</a></li>
            <!-- /TMPL_IF -->
        <!-- /TMPL_IF -->
	<!-- /TMPL_IF -->
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_borrowers" -->
    <!-- TMPL_IF name="CAN_user_borrowers_add_borrowers" -->
	<!-- TMPL_IF name="adultborrower" --><li><a id="addchild" href="/cgi-bin/koha/members/memberentry.pl?op=add&amp;guarantorid=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;category_type=C">Agregar infante</a></li><!-- /TMPL_IF -->
<!--	<li><a id="addnote" href="/cgi-bin/koha/members/addnotes.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Add Note</a></li> -->
<!-- TMPL_IF NAME="StaffMember" --><!-- TMPL_IF NAME="CAN_user_staffaccess" --> <li><a id="changepassword" href="/cgi-bin/koha/members/member-password.pl?member=<!-- TMPL_VAR NAME="borrowernumber" -->">Nueva contraseña</a></li><!-- /TMPL_IF-->
          <!-- TMPL_ELSE--> <li><a id="changepassword" href="/cgi-bin/koha/members/member-password.pl?member=<!-- TMPL_VAR NAME="borrowernumber" -->">Nueva contraseña</a></li><!-- /TMPL_IF -->	
	  <!-- /TMPL_IF -->
	  <!-- /TMPL_IF -->
	<li id="printmenuc"><a id="printpage" href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;print=page">Imprimir página</a></li>
	<li><a id="printslip" href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;print=slip">Imprimir tira</a></li>
	<li id="moremenuc"><a id="renewpatron" href="/cgi-bin/koha/members/moremember.pl?reregistration=y&amp;borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Renovar la cuenta</a></li>
    <!-- TMPL_IF NAME="CAN_user_permissions" -->
        <!-- TMPL_IF NAME="StaffMember" -->
            <!-- TMPL_IF NAME="CAN_user_staffaccess" -->
                <li><a id="patronflags" href="/cgi-bin/koha/members/member-flags.pl?member=<!-- TMPL_VAR NAME="borrowernumber" -->">Establecer permisos</a></li>
            <!-- /TMPL_IF -->
          <!-- TMPL_ELSE-->
                <li><a id="patronflags" href="/cgi-bin/koha/members/member-flags.pl?member=<!-- TMPL_VAR NAME="borrowernumber" -->">Establecer permisos</a></li>
        <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="StaffMember" --><!-- TMPL_UNLESS NAME="CAN_user_staffaccess" -->
    <!-- TMPL_IF name="CAN_user_borrowers_delete_borrowers" -->
    <li><a id="deletepatron" href="javascript:confirm_deletion();">Borrar</a></li>
    <!-- /TMPL_IF -->
    <!-- /TMPL_UNLESS -->
    <!-- TMPL_ELSE -->
    <!-- TMPL_IF name="CAN_user_borrowers_delete_borrowers" -->
    <li><a id="deletepatron" href="javascript:confirm_deletion();">Borrar</a></li>
    <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="show_override" --><li><a id="override_login" href="#">Override Login</a></li><!-- /TMPL_IF -->
</ul></div>
