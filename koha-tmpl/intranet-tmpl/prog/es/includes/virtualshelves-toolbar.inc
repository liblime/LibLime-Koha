<div id="toolbar">
	<script type="text/javascript">
	//<![CDATA[

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
		$("#deleteshelfc").empty();
	    yuiToolbar();
	 });

	// YUI Toolbar Functions

	function yuiToolbar() {
	   	    newshelfButton = new YAHOO.widget.Button("newshelf");
	   	    editshelfButton = new YAHOO.widget.Button("editshelf");
			deleteshelfButton = new YAHOO.widget.Button({
                                            id: "deleteshelf", 
                                            type: "button", 
                                            label: _("Eliminar Lista"), 
                                            container: "deleteshelfc",
											onclick: {fn:function(){confirmDelete(_("¿Está seguro de que quiere borrar este estante?"))}}
                                        });
	}

	//]]>
	</script>
	
<ul class="toolbar">
	<li><a id="newshelf" href="/cgi-bin/koha/virtualshelves/shelves.pl?shelves=1">Nueva lista</a></li>
	<!-- TMPL_IF NAME="viewshelf" --><!-- TMPL_IF name="manageshelf" -->
	<li><a id="editshelf" href="/cgi-bin/koha/virtualshelves/shelves.pl?shelfnumber=<!-- TMPL_VAR NAME="shelfnumber" -->&amp;op=modif">Editar lista</a></li>
	<li id="deleteshelfc"><!-- TMPL_IF NAME="showprivateshelves" --><a id="deleteshelf" href="/cgi-bin/koha/virtualshelves/shelves.pl?display=privateshelves&amp;shelves=1&amp;DEL-<!-- TMPL_VAR NAME="shelfnumber" -->=1">Eliminar Lista</a><!-- TMPL_ELSE --><a id="deleteshelf" href="/cgi-bin/koha/virtualshelves/shelves.pl?shelves=1&amp;DEL-<!-- TMPL_VAR NAME="shelfnumber" -->=1">Eliminar Lista</a><!-- /TMPL_IF --></li>
	<!-- /TMPL_IF --><!-- /TMPL_IF -->
</ul>
</div>
