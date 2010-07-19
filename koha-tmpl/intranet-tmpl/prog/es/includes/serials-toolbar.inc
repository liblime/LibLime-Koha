<div id="toolbar"><script type="text/javascript">
	//<![CDATA[

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
	    $("#editmenuc").empty();
	    $("#duplicate").parent().remove();
		$("#delete").parent().remove();
	 	$("#renewc").empty();
	    yuiToolbar();
	 });

	// YUI Toolbar Functions

	function yuiToolbar() {
	
    <!-- TMPL_IF NAME="subscriptionid" -->
	    var editmenu = [
	        { text: _("Editar suscripci&oacute;n"),  <!-- TMPL_IF NAME="cannotedit" -->disabled: true, <!-- /TMPL_IF --> url: "/cgi-bin/koha/serials/subscription-add.pl?op=mod&amp;subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->" },
	        { text: _("Editar como nuevo (duplicar)"), <!-- TMPL_IF NAME="cannotedit" -->disabled: true, <!-- /TMPL_IF --> url: "/cgi-bin/koha/serials/subscription-add.pl?op=dup&amp;subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->" },
			{ text: _("Borrar uscripci&oacute;n"), <!-- TMPL_IF NAME="cannotedit" -->disabled: true, <!-- /TMPL_IF --> onclick: {fn: confirm_deletion }}
	    ];
	 <!-- /TMPL_IF -->
	    new YAHOO.widget.Button("newsubscription");
	    <!-- TMPL_IF NAME="subscriptionid" -->		
		new YAHOO.widget.Button({
              id: "renew", 
              type: "link", 
			  href: "#",
              label: _("Renovar"), 
              container: "renewc",
onclick: {fn:function(){popup(<!--TMPL_VAR Name="subscriptionid"-->)}}
          });
	<!-- TMPL_IF NAME="subscriptionid" -->	  
	new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Editar"),
	        name: "editmenubutton",
	        menu: editmenu,
	        container: "editmenuc",
			
	    });
		<!-- /TMPL_IF -->
	    new YAHOO.widget.Button("renew");
	    new YAHOO.widget.Button("receive");
		<!-- /TMPL_IF -->
	}

	//]]>
	</script>
<ul class="toolbar">
    <!-- TMPL_IF NAME="biblionumber_for_new_subscription" -->
	    <li><a id="newsubscription" href="/cgi-bin/koha/serials/subscription-add.pl?biblionumber_for_new_subscription=<!-- TMPL_VAR NAME="biblionumber_for_new_subscription" -->">Nueva suscripci&oacute;n</a></li>
    <!-- TMPL_ELSE -->
	    <li><a id="newsubscription" href="/cgi-bin/koha/serials/subscription-add.pl">Nueva suscripci&oacute;n</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="subscriptionid" -->
        <!-- TMPL_UNLESS name="cannotedit" -->
            <li id="editmenuc"><a id="edit" href="/cgi-bin/koha/serials/subscription-add.pl?op=mod&amp;subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->">Editar</a></li>
        <!-- /TMPL_UNLESS -->
        <li><a id="duplicate" href="/cgi-bin/koha/serials/subscription-add.pl?op=dup&amp;subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->">Duplicado </a></li>
        <!-- TMPL_UNLESS name="cannotedit" -->
            <li id="renewc"><a id="renew" href="#" onclick="popup(<!--TMPL_VAR Name="subscriptionid"-->)">Renovar </a></li>
            <li><a id="receive" href="/cgi-bin/koha/serials/serials-edit.pl?subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->&amp;serstatus=1,3">Recibir</a></li>
            <li><a id="delete" href="javascript:confirm_deletion()">Borrar</a></li>
        <!-- /TMPL_UNLESS -->
    <!-- /TMPL_IF -->
</ul>
</div>
