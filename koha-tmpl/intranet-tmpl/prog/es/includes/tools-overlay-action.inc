          <select name="overlay_action" id="overlay_action">
            <!-- TMPL_IF NAME="overlay_action_replace" -->
                <option value="replace"  selected="selected">
            <!-- TMPL_ELSE -->
                <option value="replace">
            <!-- /TMPL_IF -->
                Reemplaze un registro existente con uno nuevo</option>
            <!-- TMPL_IF NAME="overlay_action_create_new" -->
                <option value="create_new" selected="selected">
            <!-- TMPL_ELSE -->
                <option value="create_new">
            <!-- /TMPL_IF -->
                Agregar registro ingresante</option>
            <!-- TMPL_IF NAME="overlay_action_ignore" -->
                <option value="ignore" selected="selected">
            <!-- TMPL_ELSE -->
                <option value="ignore">
            <!-- /TMPL_IF -->
                Ignorar registro ingresado (sus items pueden todavía ser procesados)</option>
        </select>
