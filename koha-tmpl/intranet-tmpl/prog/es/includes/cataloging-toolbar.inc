

<div id="toolbar">
<script type="text/javascript">
	//<![CDATA[

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
	    $("#newmenuc").empty();
	    yuiToolbar();
        yuiZ3950button();
	 });

	// YUI Toolbar Functions

	function yuiToolbar() {
	
    <!-- TMPL_IF NAME="CAN_user_editcatalogue_add_bibliographic" -->   
    <!-- TMPL_IF NAME="NOTMARC" -->
	    new YAHOO.widget.Button("newrecord");
	<!-- TMPL_ELSE -->
	
		var newmenu = [
			{ text: _("Hoja de trabajo predeterminada"), url: "/cgi-bin/koha/cataloguing/addbiblio.pl?frameworkcode=" },
			<!-- TMPL_LOOP NAME="frameworkcodeloop" -->{ text: "<!-- TMPL_VAR name="frameworktext" -->", url: "/cgi-bin/koha/cataloguing/addbiblio.pl?frameworkcode=<!-- TMPL_VAR name="value" -->"},
<!-- /TMPL_LOOP -->
		]

	    new YAHOO.widget.Button({
	        type: "menu",
	        label: _("Nuevo registro"),
	        name: "newmenubutton",
	        menu: newmenu,
	        container: "newmenuc"
	    });  
	}
    <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->

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
    /* prepare DOM for Z39.50 Search Button */
    function yuiZ3950button() {
        new YAHOO.widget.Button({
                id: "z3950search",
                type: "button",
                label: _("Búsqueda Z39.50"),
                container: "newmenuc",
                onclick: {fn:function(){PopupZ3950()}}
        });
    }
	//]]>
	</script>
	
  <div id="newmenuc">
    <!-- TMPL_IF NAME="CAN_user_editcatalogue_add_bibliographic" -->
    <!-- TMPL_IF NAME="NOTMARC" -->
		<a id="newrecord" href="/cgi-bin/koha/cataloging/addbiblio.pl">Nuevo registro</a>
	<!-- TMPL_ELSE -->
		<form name="f" action="addbiblio.pl" method="post">
		<label for="frameworkcode">Nuevo registro con hoja de trabajo:</label>
			<select name="frameworkcode" id="frameworkcode">
				<option value="">Predeterminado</option>
				<!-- TMPL_LOOP NAME="frameworkcodeloop" -->
					<option value="<!-- TMPL_VAR NAME="value" -->">
						<!-- TMPL_VAR NAME="frameworktext" -->
					</option>
				<!-- /TMPL_LOOP -->
			</select>
			<input type="submit" value="Agregar registro sin buscar">
		</form>
        <a id="z3950search" onclick="PopupZ3950(); return false;">Búsqueda Z39.50</a>
    <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->  

  </div>
</div>
