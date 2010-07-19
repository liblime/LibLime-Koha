<a onclick="javascript:if (document.getElementsByName('Coded_Fields')[0].style.display=='none'){document.getElementsByName('Coded_Fields')[0].style.display='block';} else {document.getElementsByName('Coded_Fields')[0].style.display='none';}">Filtros de información codificada</a>
<div id="yui-b" style="display:none;" name="Coded_Fields" >
<!-- SUBTYPE LIMITS -->
		<fieldset>
		<legend>Campos codificados</legend>
		<p>
		<label>Audiencia</label>
		<select name="limit" class="subtype">
            <option value="" SELECTED="selected" >Cualquiera</option>
			<option value="aud:a">juvenil, general</option>
			<option value="aud:b">pre-primaria (0-5) </option>
			<option value="aud:c">Primaria (5-8) </option>
			<option value="aud:d">niños (9-14)</option>
			<option value="aud:e">Adulto joven</option>
			<option value="aud:k">Adulto, Serio</option>
			<option value="aud:m">Adulto, General</option>
			<option value="aud:u">Desconocido</option>
		</select>
		</p>
		<p>
		<label>Imprimir</label>
        <select name="limit" class="subtype">
			<option value="" selected="selected" >cualquiera</option>
				<option value="Material-type:r">impresión normal</option>
				<option value="Material-type:d"> impresión grande</option>
				<option value="Material-type:e">formato de periódico </option>
				<option value="Material-type:f">Escritura Braille o Moon</option>
				<option value="Material-type:g">microimpresión </option>
				<option value="Material-type:h">manuscrito</option>
				<option value="Material-type:i">multimedia </option>
				<option value="Material-type:j">mini-impresión</option>
				<option value="Material-type:z">otra forma de material textual </option>
		</select>
		</p>
		<p>
		<label>Feschrift Ind.</label>
		<select name="limit" class="subtype">
			<option value="" selected="selected" >Cualquiera</option>
            <option value="Literature-Code:a">Ficci&oacute;n</option>
            <option value="Literature-Code:b">drama</option>
            <option value="Literature-Code:c">ensayos</option>
            <option value="Literature-Code:d">humor, sátira</option>
            <option value="Literature-Code:e">cartas</option>
            <option value="Literature-Code:f">historias breves</option>
            <option value="Literature-Code:g">poesía</option>
            <option value="Literature-Code:h">discursos, oratoria</option>
            <option value="Literature-Code:y">no es un texto literario</option>
            <option value="Literature-Code:z">múltiples/otras formas literarias</option>
		</select>
		</p>
        <p>
		<label>Biografía</label>
        <select name="limit" class="subtype" size="1">
            <option value="">Cualquiera</option>
            <option value="Biography-code:y">No es una biografía</option>
            <option value="Biography-code:a">autobiografía</option>
            <option value="Biography-code:b">biografía individual </option>
            <option value="Biography-code:c">biografía colectiva</option>
            <option value="Biography-code:d">contiene datos biográficos</option>
		</select>
        </p>
        <p>
		<label>Ilustración</label>
        <select name="limit" class="subtype" size="1">
            <option value="">Cualquiera</option>
            <option value="Illustration-Code:a">ilustraciones</option>
            <option value="Illustration-Code:b">mapas</option>
            <option value="Illustration-Code:c">retratos</option>
            <option value="Illustration-Code:d">mapas</option>
            <option value="Illustration-Code:e">planos</option>
            <option value="Illustration-Code:f">placas</option>
            <option value="Illustration-Code:g">música</option>
            <option value="Illustration-Code:h">facsímiles </option>
            <option value="Illustration-Code:i">escudo de armas</option>
            <option value="Illustration-Code:j">tablas geneal&ocute;gicas</option>
            <option value="Illustration-Code:k">fromularios</option>
            <option value="Illustration-Code:l">muestras </option>
            <option value="Illustration-Code:m">grabaciones sonoras</option>
            <option value="Illustration-Code:n">transparencias</option>
            <option value="Illustration-Code:o">iluminaciones</option>
            <option value="Illustration-Code:y">sin ilustraciones</option>
        </select>
        </p>
		<p>
		<label>Contenido</label>
		<select name="limit" class="subtype">
			<option value="" >Cualquiera</option>
            <option value="ctype:a" >bibliografía</option>
            <option value="ctype:b" >catálogo</option>
            <option value="ctype:c" >índice</option>
            <option value="ctype:d" >resumen</option>
            <option value="ctype:e" >diccionario</option>
            <option value="ctype:f" >enciclopedia</option>
            <option value="ctype:g" >directorio</option>
            <option value="ctype:h" >descripci&oacute;n del proyecto</option>
            <option value="ctype:i" >estadísticas</option>
            <option value="ctype:j" >libros de texto programados</option>
            <option value="ctype:k" >patente</option>
            <option value="ctype:l" >estandar</option>
            <option value="ctype:m" >disertación o tésis</option>
            <option value="ctype:n" > leyes y legislación</option>
            <option value="ctype:o" >tabla numérica</option>
            <option value="ctype:p" >informe técnico</option>
            <option value="ctype:q" >enunciado de examen</option>
            <option value="ctype:r" >compendios/revisiones en literatura</option>
            <option value="ctype:s" >tratados</option>
            <option value="ctype:t" >historietas o cómics</option>
            <option value="ctype:z" >otro</option>
		</select>
        </p>
        <p>
		<label>Tipos de vídeo</label>
		<select name="limit" class="subtype">
            <option value="">Cualquiera</option>
			<option value="Video-mt:a">película de cine</option>
			<option value="Video-mt:b">proyección visual</option>
			<option value="Video-mt:c">grabación de vídeo</option>
		</select>
        </p>
		</fieldset>
		<fieldset>
		<legend>Publicaciones periódicas</legend><p>
		<p>
		<label>Serie</label>
		<select name="limit" class="subtype">
           <option value="">Cualquier tipo</option>
           <option value="Type-Of-Serial:a">Periódica</option>
			<option value="Type-Of-Serial:b">Series monográficas</option>
			<option value="Type-Of-Serial:c">Periódico</option>
			<option value="Type-Of-Serial:z">Otro</option>
		</select>
		</p>
		<p>
		<label>Periodicidad</label>
		<select name="limit" class="subtype">
			<option value="">Cualquiera</option>
				<option value="Frequency-code:a">Diario</option>
				<option value="Frequency-code:b">Dos veces por semana</option>
				<option value="Frequency-code:c">Semanal</option>
				<option value="Frequency-code:d">Bisemanal</option>
				<option value="Frequency-code:e">Quincenal</option>
				<option value="Frequency-code:f">Mensual</option>
				<option value="Frequency-code:g">Bimestral</option>
				<option value="Frequency-code:h">Trimestral</option>
				<option value="Frequency-code:i">Tres veces al año</option>
				<option value="Frequency-code:j">Semestral</option>
				<option value="Frequency-code:k">Anual</option>
				<option value="Frequency-code:l">Bianual</option>
				<option value="Frequency-code:m">Trienio</option>
				<option value="Frequency-code:n">Tres veces a la semana</option>
				<option value="Frequency-code:o">Tres veces al mes</option>
				<option value="Frequency-code:u">Desconocido</option>
				<option value="Frequency-code:y">Sin periodicidad</option>
				<option value="Frequency-code:i">Otro</option>
		</select>
		</p>
		<p>
		<label>Regularidad</label>
		<select name="limit" class="subtype">
            <option value="">Cualquier regularidad</option>
				<option value="Regularity-code:u">Desconocido</option>
				<option value="Regularity-code:a">Regular</option>
				<option value="Regularity-code:b">Normalizado irregular </option>
				<option value="Regularity-code:y">irregular</option>
		</select>
        </p>

        </fieldset>
		<fieldset>
		<legend>Pintura</legend><p>
		<select name="limit" class="subtype">
				<option value="">Cualquiera</option>
				<option value="Graphics-type:a">collage</option>
				<option value="Graphics-type:b">dibujo</option>
				<option value="Graphics-type:c">pinrtura</option>
				<option value="Graphics-type:d">reproducción fotomecánica</option>
				<option value="Graphics-type:e">negativo fotográfico</option>
				<option value="Graphics-type:f">impresión fotográfica</option>
				<option value="Graphics-type:h">imagen</option>
				<option value="Graphics-type:i">imprimir</option>
				<option value="Graphics-type:k">dibujo técnico</option>
				<option value="Graphics-type:z">otros tipos de gráficos no proyectados</option>
		</select>
		<select name="limit" class="subtype">
            <option value="">cualquiera</option>
            <option value="Graphics-support:a">lienzo</option>
            <option value="Graphics-support:b">cartulina</option>
            <option value="Graphics-support:c">cartulina/cartón</option>
            <option value="Graphics-support:d">vidrio</option>
            <option value="Graphics-support:j">yeso</option>
            <option value="Graphics-support:k">tableso duro</option>
            <option value="Graphics-support:l">porcelana </option>
            <option value="Graphics-support:m">piedra</option>
            <option value="Graphics-support:n">madera</option>
            <option value="Graphics-support:u">desconocido</option>
            <option value="Graphics-support:v">colección mixta</option>
            <option value="Graphics-support:e">sintéticos </option>
            <option value="Graphics-support:f">piel</option>
            <option value="Graphics-support:g">textil</option>
            <option value="Graphics-support:h">metal</option>
            <option value="Graphics-support:i">papel</option>
            <option value="Graphics-support:z">otros</option>
		</select>
        </p>

</fieldset>
</div>
