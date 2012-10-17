// staff-global.js
if (typeof KOHA == "undefined" || !KOHA) {
    var KOHA = {};
}

function _(s) { return s } // dummy function for gettext

 $(document).ready(function() {
	$('#header_search').tabs( { show : function(e, ui) { $('#header_search > div:not(.ui-tabs-hide)').find('input[type="text"]').eq(0).focus(); } });
 	$(".focus").focus();
    $( ".tabs-bottom .ui-tabs-nav, .tabs-bottom .ui-tabs-nav > *" ).removeClass( "ui-corner-all ui-corner-top" ).addClass( "ui-corner-bottom" );
	$(".close").click(function(){ window.close(); });
	if($("#header_search #tabs-checkin_search").length > 0){ $(document).bind('keydown','Alt+r',function (){ $("#header_search").tabs("select","#tabs-checkin_search"); $("#ret_barcode").focus(); }); } else { $(document).bind('keydown','Alt+r',function (){ location.href="/cgi-bin/koha/circ/returns.pl"; }); }
	if($("#header_search #tabs-circ_search").length > 0){
        $(document).bind('keydown','Alt+u',function (){ $("#header_search").tabs("select","#tabs-circ_search"); $("#findborrower").focus(); });
    } else {
        $(document).bind('keydown','Alt+u',function(){ location.href="/cgi-bin/koha/circ/circulation.pl"; });
    }
	if($("#header_search #tabs-catalog_search").length > 0){ $(document).bind('keydown','Alt+q',function (){ $("#header_search").tabs("select","#tabs-catalog_search"); $("#search-form").focus(); }); } else { $(document).bind('keydown','Alt+q',function(){ location.href="/cgi-bin/koha/catalogue/search.pl"; }); }
 });
 
             YAHOO.util.Event.onContentReady("header", function () {
				var oMoremenu = new YAHOO.widget.Menu("moremenu", { zindex: 2 });

				function positionoMoremenu() {
					oMoremenu.align("tl", "bl");
				}

                oMoremenu.subscribe("beforeShow", function () {
                    if (this.getRoot() == this) {
						positionoMoremenu();
                    }
                });

				oMoremenu.render();

                oMoremenu.cfg.setProperty("context", ["showmore", "tl", "bl"]);

				function onShowMoreClick(p_oEvent) {
                    // Position and display the menu        
                    positionoMoremenu();
                    oMoremenu.show();
                    // Stop propagation and prevent the default "click" behavior
                    YAHOO.util.Event.stopEvent(p_oEvent);	
				}

				YAHOO.util.Event.addListener("showmore", "click", onShowMoreClick);

                YAHOO.widget.Overlay.windowResizeEvent.subscribe(positionoMoremenu);
            });

YAHOO.util.Event.onContentReady("changelanguage", function () {
                var oMenu = new YAHOO.widget.Menu("sublangs", { zindex: 2 });

	            function positionoMenu() {
                    oMenu.align("bl", "tl");
                }

                oMenu.subscribe("beforeShow", function () {
                    if (this.getRoot() == this) {
						positionoMenu();
                    }
                });

                oMenu.render();

				oMenu.cfg.setProperty("context", ["showlang", "bl", "tl"]);

				function onYahooClick(p_oEvent) {
                    // Position and display the menu        
                    positionoMenu();
                    oMenu.show();
                    // Stop propagation and prevent the default "click" behavior
                    YAHOO.util.Event.stopEvent(p_oEvent);
                }

				YAHOO.util.Event.addListener("showlang", "click", onYahooClick);

				YAHOO.widget.Overlay.windowResizeEvent.subscribe(positionoMenu);
            });
			
// http://jennifermadden.com/javascript/stringEnterKeyDetector.html
function checkEnter(e){ //e is event object passed from function invocation
	var characterCode; // literal character code will be stored in this variable
	if(e && e.which){ //if which property of event object is supported (NN4)
		e = e;
		characterCode = e.which; //character code is contained in NN4's which property
	} else {
		e = event;
		characterCode = e.keyCode; //character code is contained in IE's keyCode property
	}

	if(characterCode == 13){ //if generated character code is equal to ascii 13 (if enter key)
		return false;
	} else {
		return true;
	}
}
