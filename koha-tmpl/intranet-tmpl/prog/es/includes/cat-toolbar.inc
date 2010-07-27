<div id="toolbar">
	
	<script type="text/javascript">
	//<![CDATA[
	<!-- TMPL_IF NAME="CAN_user_editcatalogue" -->
	/* this function open a popup to search on z3950 server.  */
	function PopupZ3950() {
		var strQuery = GetZ3950Terms();
		if(strQuery){
			window.open("/cgi-bin/koha/cataloguing/z3950_search.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->"+strQuery,"z3950search",'width=740,height=450,location=yes,toolbar=no,scrollbars=yes,resize=yes');
		} 
	}

	/* provide Z3950 search points */
	function GetZ3950Terms(){
		var strQuery="&frameworkcode=";
		<!-- TMPL_LOOP NAME='z3950_search_params' -->
			strQuery += "&" + "<!-- TMPL_VAR NAME="name" -->" + "=" + "<!-- TMPL_VAR NAME="encvalue" -->";
		<!-- /TMPL_LOOP -->
		return strQuery;
	}
	<!-- /TMPL_IF -->
	function addToShelf() {	window.open('/cgi-bin/koha/virtualshelves/addbybiblionumber.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->','Add_to_virtualshelf','width=500,height=400,toolbar=false,scrollbars=yes');
	}
	function printBiblio() {window.open('/cgi-bin/koha/catalogue/detailprint.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->','Print_Biblio','width=700,height=500,toolbar=false,scrollbars=yes');
	}
function confirm_deletion() {
		var count = <!-- TMPL_VAR NAME="count" -->;
        var is_confirmed;
	if (count>0){
		    is_confirmed= alert(_('There are [ '+ count +' ] item(s) attached to this record \n You must delete all items before deleting this record.'));
		    } else{
		    is_confirmed= confirm(_('¿Está seguro de que quiere borrar este registro?'));
	}

     if (is_confirmed) {
        if (count>0){
	// 	window.location="/cgi-bin/koha/catalogue/detail.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->";
		} else {
			window.location="/cgi-bin/koha/cataloguing/addbiblio.pl?op=delete&amp;biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->";
		}
	} else {
		return false;
	}
}

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
	    $("#edititems").parent().remove();
	    $("#duplicatebiblio").parent().remove();
		$("#deletebiblio").parent().remove();
		$("#newitem").parent().remove();
		$("#newsub").parent().remove();
	    $("#editmenuc").empty();
		$("#newmenuc").empty();
		$("#addtoshelfc").empty();
		$("#printbiblioc").empty();
		$("#export").remove();
		$("#addtoshelfc").before("<li id=\"savemenuc\"><\/li>");
		$("#z3950searchc").empty();
	    yuiToolbar();
	 });

	// YUI Toolbar Functions

	function yuiToolbar() {
		var newmenu = [
        <!-- TMPL_IF NAME="CAN_user_editcatalogue_add_bibliographic" -->
			{text: _("Nuevo registro"), url: "/cgi-bin/koha/cataloguing/addbiblio.pl" },
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="CAN_user_editcatalogue_add_items" -->
			{text: _("Nuevo ítem"), url: "/cgi-bin/koha/cataloguing/additem.pl?op=addadditionalitem&amp;biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&amp;itemnumber=<!-- TMPL_VAR NAME="additemnumber" -->#additema" },
        <!-- /TMPL_IF -->
			{text: _("Nueva suscripci&oacute;n"), url: "/cgi-bin/koha/serials/subscription-add.pl?biblionumber_for_new_subscription=<!-- TMPL_VAR NAME="biblionumber" -->"},
		];
	
	    var editmenu = [
        <!-- TMPL_IF NAME="CAN_user_editcatalogue_edit_bibliographic" -->
	        { text: _("Editar registro"), url: "/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&amp;frameworkcode=&amp;op=" },
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="CAN_user_editcatalogue_edit_items" -->
	        { text: _("Editar ítems"), url: "/cgi-bin/koha/cataloguing/additem.pl?op=edititem&amp;biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->" },
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="CAN_user_editcatalogue_add_bibliographic" -->
	        { text: _("Editar como nuevo (duplicar)"), url: "/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&amp;frameworkcode=&amp;op=duplicate" },
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="CAN_user_editcatalogue_delete_bibliographic" -->
			{ text: _("Eliminar Registro"), onclick: {fn: confirm_deletion }<!-- TMPL_IF NAME="count" -->,id:'disabled'<!-- /TMPL_IF --> }
        <!-- /TMPL_IF -->
	    ];
		
		var savemenu = [
		{ text: _("MODS (XML)"), url: "/cgi-bin/koha/catalogue/export.pl?format=mods&op=export&bib=<!-- TMPL_VAR NAME="biblionumber" -->" },
		{ text: _("Dublin Core (XML)"), url: "/cgi-bin/koha/catalogue/export.pl?format=dc&op=export&bib=<!-- TMPL_VAR NAME="biblionumber" -->" },
		{ text: _("MARCXML"), url: "/cgi-bin/koha/catalogue/export.pl?format=marcxml&op=export&bib=<!-- TMPL_VAR NAME="biblionumber" -->" },
		{ text: _("MARC (non-Unicode/MARC-8)"), url: "/cgi-bin/koha/catalogue/export.pl?format=marc8&op=export&bib=<!-- TMPL_VAR NAME="biblionumber" -->" },
		{ text: _("MARC (Unicode/UTF-8)"), url: "/cgi-bin/koha/catalogue/export.pl?format=utf8&op=export&bib=<!-- TMPL_VAR NAME="biblionumber" -->" }
		];

	    new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Guardar"),
	        name: "savemenubutton",
	        menu: savemenu,
	        container: "savemenuc"
	    });
	    
		new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Editar"),
	        name: "editmenubutton",
	        menu: editmenu,
	        container: "editmenuc"
	    });
	    
		new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Nuevo"),
	        name: "newmenubutton",
	        menu: newmenu,
	        container: "newmenuc"
	    });
		
		new YAHOO.widget.Button({
			id: "z3950search", 
			type: "button", 
			label: _("Búsqueda Z39.50"), 
			container: "z3950searchc",
			onclick: {fn:function(){PopupZ3950()}}
		});

		var addtoshelfButton = new YAHOO.widget.Button({
                                            id: "addtoshelf", 
                                            type: "button", 
                                            label: _("Agregar a lista"), 
                                            container: "addtoshelfc",
											onclick: {fn: addToShelf }
                                        });
										
		var printbiblioButton = new YAHOO.widget.Button({
                                            id: "printbiblio", 
                                            type: "button", 
                                            label: _("Imprimir"), 
                                            container: "printbiblioc",
											onclick: {fn: printBiblio }
                                        });

	    var newbiblioButton = new YAHOO.widget.Button("newbiblio");
	    var placeholdButton = new YAHOO.widget.Button("placehold");
		
	}

	//]]>
	</script>
	
<form method="post" name="f" id="f" action="/cgi-bin/koha/cataloguing/addbiblio.pl" onsubmit="return Check();">

<ul class="toolbar">
	<!-- TMPL_IF NAME="CAN_user_editcatalogue" -->
	<li id="newmenuc"></li>
	<!-- TMPL_IF NAME="CAN_user_editcatalogue_add_bibliographic" -->
	<li><a id="newbiblio" href="/cgi-bin/koha/cataloguing/addbiblio.pl">Nuevo registro</a></li>
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_editcatalogue_add_items" -->
	<li><a id="newitem" href="/cgi-bin/koha/cataloguing/additem.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">Nuevo ítem</a></li>
	<!-- /TMPL_IF -->
	<li><a id="newsub" href="/cgi-bin/koha/serials/subscription-add.pl?biblionumber_for_new_subscription=<!-- TMPL_VAR NAME="biblionumber" -->">Nueva suscripci&oacute;n</a></li>
	<li id="editmenuc"><a id="editbiblio" href="/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&amp;frameworkcode=<!--TMPL_VAR Name="current_framework" -->&amp;op=">Editar registro</a></li>
	<!-- TMPL_IF NAME="CAN_user_editcatalogue_edit_items" -->
	<li><a id="edititems" href="/cgi-bin/koha/cataloguing/additem.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">Editar ítems</a></li>
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_editcatalogue_add_bibliographic" -->
	<li><a id="duplicatebiblio" href="/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&amp;frameworkcode=<!--TMPL_VAR Name="current_framework" -->&amp;op=duplicate">Registro duplicado</a></li>
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_editcatalogue_delete_bibliographic" -->
	<li><a id="deletebiblio" href="/cgi-bin/koha/cataloguing/addbiblio.pl?op=delete&amp;biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">Borrar</a></li>
	<!-- /TMPL_IF -->
	<!-- /TMPL_IF -->
	<li id="addtoshelfc"><a id="addtoshelf" href="/cgi-bin/koha/virtualshelves/addbybiblionumber.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">Agregar al estante</a></li>
	<li id="printbiblioc"><a id="printbiblio" href="/cgi-bin/koha/catalogue/detailprint.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">Imprimir</a></li>
	<!-- TMPL_IF NAME="CAN_user_reserveforothers" -->
	<!-- TMPL_IF NAME="CAN_user_reserveforothers_add_holds" -->
	<!-- TMPL_UNLESS NAME="norequests" --><li><a id="placehold" href="/cgi-bin/koha/reserve/request.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">Ingrese reserva</a></li><!-- /TMPL_UNLESS -->
	<!-- /TMPL_IF -->
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_editcatalogue" --><li id="z3950searchc"><input type="button" id="z3950search" value="Búsqueda Z39.50" onclick="PopupZ3950(); return false;"></li><!-- /TMPL_IF -->
    </ul>
</form>
</div>

