<form name="f" method="get" action="auth_finder.pl">
            <input type="hidden" name="op" value="do_search" />
            <input type="hidden" name="type" value="intranet" />
            <input type="hidden" name="nbstatements" value="<!-- TMPL_VAR NAME="nbstatements" -->" />
            <input type="hidden" name="index" value="<!-- TMPL_VAR NAME="index" -->" />
                <fieldset class="rows"><ol><li>
                    <span class="label">Tipo de autoridad</span>
                    <!-- TMPL_VAR NAME="authtypecode" -->
                    <input type="hidden" name="authtypecode" value="<!-- TMPL_VAR NAME="authtypecode" -->" />
                </li>
                <li>
                    <label for="mainmainentry">Entrada Principal (sólo $a)</label>
                    <input type="hidden" name="marclist" value="mainmainentry" />
                    <input type="hidden" name="and_or" value="and" />
                    <input type="hidden" name="excluding" value="" />
                    <select name="operator" id="mainmainentry">
                        <option value="contains">contiene</option>
                        <option value="start">comienza con</option>
                        <option value="is">es exactamente</option>
                    </select>
                    <input type="text" name="value_mainstr" value="<!-- TMPL_VAR ESCAPE="HTML" name="value_mainstr" -->" />
                </li>
                <li>
                    <label for="mainentry">Entrada Principal</label>
                    <input type="hidden" name="marclist" value="mainentry" />
                    <input type="hidden" name="and_or" value="and" />
                    <input type="hidden" name="excluding" value="" />
                    <select name="operator" id="mainentry">
                        <option value="contains">contiene</option>
                        <option value="start">comienza con</option>
                        <option value="is">es exactamente</option>
                    </select>
                    <input type="text" name="value_main" value="<!-- TMPL_VAR ESCAPE="HTML" name="value_main" -->" />
                </li>
                <li>
                    <label for="marclist">En cualquier parte</label>
                    <input type="hidden" name="marclist" value="" />
                    <input type="hidden" name="and_or" value="and" />
                    <input type="hidden" name="excluding" value="" />
                    <select name="operator" id="marclist">
                        <option value="contains">contiene</option>
                        <option value="start">comienza con</option>
                        <option value="is">es exactamente</option>
                    </select>
                    <input type="text" name="value_any" value="<!-- TMPL_VAR ESCAPE="HTML" name="value_any" -->" />
                </li>
		<li>
		<label for="orderby">Ordenar por </label>
		<select name="orderby" id="orderby">
		    <option value="">No hay pedido</option>
            <option value="HeadingAsc" selected="selected">Ascendente por cabecera</option>
            <option value="HeadingDsc">Descendente por cabecera</option>
        </select>
		</li></ol></fieldset>
            <fieldset class="action"> <input type="submit" value="Iniciar b&uacute;squeda" class="submit"> <a class="cancel close" href="#">Cancelar</a></fieldset>
</form>
