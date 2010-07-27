          <select name="item_action" id="item_action">
            <!-- TMPL_IF NAME="item_action_always_add" -->
                <option value="always_add" selected="selected">
            <!-- TMPL_ELSE -->
                <option value="always_add">
            <!-- /TMPL_IF -->
                Siempre agregar ítems</option>
            <!-- TMPL_IF NAME="item_action_add_only_for_matches" -->
                <option value="add_only_for_matches" selected="selected">
            <!-- TMPL_ELSE -->
                <option value="add_only_for_matches">
            <!-- /TMPL_IF -->
                Añadir ítems sólo si se localizó un registro bibliográfico coincidente</option>
            <!-- TMPL_IF NAME="item_action_add_only_for_new" -->
                <option value="add_only_for_new" selected="selected">
            <!-- TMPL_ELSE -->
                <option value="add_only_for_new">
            <!-- /TMPL_IF -->
                Añadir ítems sólo si no se localizó un registro bibliográfico coincidente</option>
            <!-- TMPL_IF NAME="item_action_ignore" -->
                <option value="ignore" selected="selected">
            <!-- TMPL_ELSE -->
                <option value="ignore">
            <!-- /TMPL_IF -->
                Ignorar items</option>
        </select>
