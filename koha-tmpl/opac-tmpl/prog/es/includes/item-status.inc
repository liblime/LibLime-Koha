<!-- TMPL_IF name="notforloan_per_itemtype" -->
    No para prestamo <!-- TMPL_IF NAME="notforloanvalue" -->(<!-- TMPL_VAR NAME="notforloanvalue" -->)<!-- /TMPL_IF -->
<!-- TMPL_ELSE -->
    <!-- TMPL_IF name="datedue" -->
        <!-- TMPL_IF name="OPACShowCheckoutName" -->
            Checked out to <!-- TMPL_VAR NAME="cardnumber" --> <!-- TMPL_VAR NAME="firstname" --> <!-- TMPL_VAR NAME="surname" -->
        <!-- TMPL_ELSE -->
            Prestado
        <!-- /TMPL_IF -->
    <!-- TMPL_ELSE -->
        <!-- TMPL_IF name="itemnotforloan" -->
            <!-- TMPL_VAR NAME="notforloanvalue" -->
        <!-- TMPL_ELSE -->
            <!-- TMPL_IF name="itemlost"-->
                <!-- TMPL_IF name="lostimageurl"-->
                    <img src="<!-- TMPL_VAR NAME="lostimageurl" -->" alt="<!-- TMPL_VAR NAME="lostimagelabel" -->" title="<!-- TMPL_VAR NAME="lostimagelabel" -->">
                <!-- TMPL_ELSE -->
                    Ítem perdido
                <!-- /TMPL_IF -->
            <!-- TMPL_ELSE -->
                <!-- TMPL_IF NAME="wthdrawn" -->
                    Ítem retirado
                <!-- TMPL_ELSIF NAME="damaged" -->
                    Ítem dañado
                <!-- TMPL_ELSIF NAME="otherstatus_description" -->
                    <!-- TMPL_VAR NAME="otherstatus_description" -->
                <!-- TMPL_ELSIF Name="transfertwhen" -->
                    En tránsito de <!-- TMPL_VAR NAME="transfertfrom" --> a <!-- TMPL_VAR NAME="transfertto" --> desde <!-- TMPL_VAR NAME="transfertwhen" -->
                <!-- TMPL_ELSE -->
                    <!-- TMPL_IF NAME="waiting" -->Reservado<!-- TMPL_ELSE -->Disponible<!-- /TMPL_IF -->
                <!-- /TMPL_IF -->
            <!-- /TMPL_IF -->
        <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->
<!-- /TMPL_IF -->
