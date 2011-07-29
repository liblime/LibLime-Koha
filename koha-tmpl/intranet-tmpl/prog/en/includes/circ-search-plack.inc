
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Circulation Resident Search Box -->

<div id="header_search">
    <!-- TMPL_INCLUDE NAME="patron-search-box.inc" -->
<!-- TMPL_IF NAME="CAN_user_circulate" -->
<div id="checkin_search" class="residentsearch" style="display:none;">
    <p class="tip">Scan a barcode to check in:</p>
    <form method="post" action="/cgi-bin/koha/circ/returns.pl">
        <input name="barcode" id="ret_barcode" size="40" accesskey="r" />
        <input value="Submit" class="submit" type="submit" />
    </form>
</div><!-- /TMPL_IF -->
<!-- TMPL_IF NAME="CAN_user_catalogue" -->
<div id="catalog_search" class="residentsearch" style="display:none;">
    <p class="tip">Enter search keywords:</p>
    <form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
        <input type="text" name="q" id="search-form" size="40" accesskey="q" />
        <input type="submit" class="submit" value="Submit"/>
    </form>
</div><!-- /TMPL_IF -->

<ul>
    <!-- TMPL_IF NAME="CAN_user_circulate" --><li id="circtab0"><a href="#circ_search"    onclick="return _circtab(0)">Check Out</a></li><!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_circulate" --><li id="circtab1"><a href="#checkin_search" onclick="return _circtab(1)">Check In</a></li><!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_catalogue" --><li id="circtab2"><a href="#catalog_search" onclick="return _circtab(2)">Search the Catalog</a></li><!-- /TMPL_IF -->
</ul>   

</div>
<script>
function _circtab(idx) {
   var tabs = new Array(
      ['circ_search'   ,'findborrower'],
      ['checkin_search','ret_barcode' ],
      ['catalog_search','search-form' ]
   );
   for(var i=0;i<3;i++) {
      if($('#circtab'+i)) {
         var tab = tabs[i][0];
         if(i==idx) { $('#circtab'+i).addClass('ui-tabs-selected');   $('#'+tab).css('display','block'); }
         else       { $('#circtab'+i).removeClass('ui-tabs-selected');$('#'+tab).css('display','none');  }
      }
   }
   $('#'+tabs[idx][1]).focus();
   return false; // don't jump to anchor
   //$('html').animate({scrollTop:0});
   //$('body').animate({scrollTop:0});
}
</script>
<!-- End Circulation Resident Search Box -->
