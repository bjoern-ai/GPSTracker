<?php
/**
 * Plugin Name:       Fotospur
 * Description:       Block „Fotospur“: zeigt die Fotos einer Tour an der Stelle der Tourspur-Strecke, an der sie aufgenommen wurden.
 * Version:           1.1.1
 * Requires at least: 6.5
 * Requires PHP:      7.4
 * Author:            Björn Czibulla
 * Plugin URI:        https://github.com/bjoern-ai/GPSTracker
 * License:           MIT
 * Text Domain:       tourspur-fotospur
 */

defined( 'ABSPATH' ) || exit;

const TOURSPUR_FOTOSPUR_VERSION = '1.1.1';

/**
 * GPX-Dateien in der Mediathek erlauben.
 */
add_filter(
	'upload_mimes',
	function ( $mimes ) {
		$mimes['gpx'] = 'application/gpx+xml';
		return $mimes;
	}
);

/**
 * WordPress erkennt GPX am Inhalt als XML oder Text und würde den Upload ablehnen.
 */
add_filter(
	'wp_check_filetype_and_ext',
	function ( $data, $file, $filename ) {
		if ( 'gpx' === strtolower( pathinfo( $filename, PATHINFO_EXTENSION ) ) ) {
			$data['ext']             = 'gpx';
			$data['type']            = 'application/gpx+xml';
			$data['proper_filename'] = false;
		}
		return $data;
	},
	10,
	3
);

add_action(
	'init',
	function () {
		$url = plugin_dir_url( __FILE__ );
		wp_register_style( 'tourspur-fotospur', $url . 'assets/fotospur.css', array(), TOURSPUR_FOTOSPUR_VERSION );
		wp_register_script( 'tourspur-fotospur', $url . 'assets/fotospur.js', array(), TOURSPUR_FOTOSPUR_VERSION, array( 'in_footer' => true ) );
		wp_register_script(
			'tourspur-fotospur-editor',
			$url . 'assets/editor.js',
			array( 'wp-blocks', 'wp-element', 'wp-block-editor', 'wp-components', 'wp-data', 'wp-core-data', 'wp-server-side-render' ),
			TOURSPUR_FOTOSPUR_VERSION,
			true
		);

		$args = array(
			'api_version'     => 3,
			'title'           => 'Fotospur',
			'description'     => 'Fotos entlang der Tourspur-Strecke.',
			'category'        => 'media',
			'icon'            => 'location-alt',
			'editor_script'   => 'tourspur-fotospur-editor',
			'style'           => 'tourspur-fotospur',
			'attributes'      => array(
				'gpxId'    => array( 'type' => 'number', 'default' => 0 ),
				'imageIds' => array( 'type' => 'array', 'default' => array(), 'items' => array( 'type' => 'number' ) ),
				'name'     => array( 'type' => 'string', 'default' => '' ),
			),
			'supports'        => array( 'html' => false, 'align' => array( 'wide' ) ),
			'render_callback' => 'tourspur_fotospur_render',
		);

		register_block_type( 'tourspur/fotospur', $args );

		// Früherer Name aus der ersten Version: bestehende Beiträge funktionieren weiter,
		// im Block-Einfügen erscheint er aber nicht mehr.
		if ( ! WP_Block_Type_Registry::get_instance()->is_registered( 'rollermomente/fotospur' ) ) {
			$legacy             = $args;
			$legacy['supports'] = array_merge( $args['supports'], array( 'inserter' => false ) );
			register_block_type( 'rollermomente/fotospur', $legacy );
		}
	}
);

/**
 * Im Editor läuft der Inhalt in einem eigenen Rahmen, dort braucht die Vorschau das Skript ebenfalls.
 */
add_action(
	'enqueue_block_assets',
	function () {
		if ( is_admin() ) {
			wp_enqueue_script( 'tourspur-fotospur' );
		}
	}
);

/**
 * Kürzester Abstand auf der Erdkugel in Kilometern.
 */
function tourspur_fotospur_km( $lat1, $lon1, $lat2, $lon2 ) {
	$r  = 6371.0088;
	$p1 = deg2rad( $lat1 );
	$p2 = deg2rad( $lat2 );
	$h  = sin( ( $p2 - $p1 ) / 2 ) ** 2 + cos( $p1 ) * cos( $p2 ) * sin( deg2rad( $lon2 - $lon1 ) / 2 ) ** 2;
	return 2 * $r * asin( min( 1, sqrt( $h ) ) );
}

/**
 * Liest eine GPX-Datei: Punkte mit lat, lon, ele, time (Unix) und km.
 */
function tourspur_fotospur_read_gpx( $path ) {
	if ( ! $path || ! is_readable( $path ) ) {
		return null;
	}
	$prev = libxml_use_internal_errors( true );
	$xml  = simplexml_load_file( $path, 'SimpleXMLElement', LIBXML_NONET );
	libxml_use_internal_errors( $prev );
	if ( ! $xml ) {
		return null;
	}
	$xml->registerXPathNamespace( 'g', 'http://www.topografix.com/GPX/1/1' );
	$nodes = $xml->xpath( '//g:trkpt' );
	if ( ! $nodes ) {
		$nodes = $xml->xpath( '//*[local-name()="trkpt"]' );
	}
	$pts = array();
	$km  = 0.0;
	foreach ( (array) $nodes as $n ) {
		$lat = (float) $n['lat'];
		$lon = (float) $n['lon'];
		$ele = isset( $n->ele ) ? (float) $n->ele : 0.0;
		$t   = isset( $n->time ) ? strtotime( (string) $n->time ) : null;
		if ( $pts ) {
			$last = end( $pts );
			$km  += tourspur_fotospur_km( $last['lat'], $last['lon'], $lat, $lon );
		}
		$pts[] = array( 'lat' => $lat, 'lon' => $lon, 'ele' => $ele, 'time' => $t ?: null, 'km' => $km );
	}
	return count( $pts ) > 1 ? $pts : null;
}

/**
 * Aufnahmezeit (Unix) und GPS-Position eines Fotos aus der Mediathek.
 */
function tourspur_fotospur_photo_info( $id ) {
	$file = function_exists( 'wp_get_original_image_path' ) ? wp_get_original_image_path( $id ) : get_attached_file( $id );
	$time = null;
	$pos  = null;

	if ( $file && function_exists( 'exif_read_data' ) && is_readable( $file ) ) {
		$exif = @exif_read_data( $file ); // phpcs:ignore WordPress.PHP.NoSilencedErrors
		if ( $exif ) {
			if ( ! empty( $exif['DateTimeOriginal'] ) ) {
				$local  = DateTime::createFromFormat( 'Y:m:d H:i:s', $exif['DateTimeOriginal'], wp_timezone() );
				$offset = $exif['OffsetTimeOriginal'] ?? '';
				if ( $offset && preg_match( '/^[+-]\d\d:\d\d$/', $offset ) ) {
					$local = DateTime::createFromFormat( 'Y:m:d H:i:sP', $exif['DateTimeOriginal'] . $offset );
				}
				$time = $local ? $local->getTimestamp() : null;
			}
			if ( ! empty( $exif['GPSLatitude'] ) && ! empty( $exif['GPSLongitude'] ) ) {
				$deg = function ( $v ) {
					$f = function ( $r ) {
						$p = explode( '/', (string) $r );
						return count( $p ) === 2 && (float) $p[1] ? (float) $p[0] / (float) $p[1] : (float) $p[0];
					};
					return $f( $v[0] ) + $f( $v[1] ) / 60 + $f( $v[2] ) / 3600;
				};
				$lat = $deg( $exif['GPSLatitude'] ) * ( ( $exif['GPSLatitudeRef'] ?? 'N' ) === 'S' ? -1 : 1 );
				$lon = $deg( $exif['GPSLongitude'] ) * ( ( $exif['GPSLongitudeRef'] ?? 'E' ) === 'W' ? -1 : 1 );
				$pos = array( $lat, $lon );
			}
		}
	}

	if ( ! $time ) {
		// WordPress speichert die Kamerazeit ohne Zeitzone, als wäre sie UTC.
		$meta = wp_get_attachment_metadata( $id );
		$ts   = $meta['image_meta']['created_timestamp'] ?? 0;
		if ( $ts ) {
			$local = DateTime::createFromFormat( 'Y-m-d H:i:s', gmdate( 'Y-m-d H:i:s', (int) $ts ), wp_timezone() );
			$time  = $local ? $local->getTimestamp() : null;
		}
	}
	return array( $time, $pos );
}

/**
 * Baut die Daten für fotospur.js. Ergebnis wird zwischengespeichert.
 */
function tourspur_fotospur_data( $gpx_id, $image_ids, $name ) {
	$gpx_path = get_attached_file( $gpx_id );
	$key      = 'tourspur_fotospur_' . md5( wp_json_encode( array( $gpx_id, $image_ids, $name, $gpx_path ? @filemtime( $gpx_path ) : 0, TOURSPUR_FOTOSPUR_VERSION ) ) ); // phpcs:ignore
	$cached   = get_transient( $key );
	if ( false !== $cached ) {
		return $cached;
	}

	$pts = tourspur_fotospur_read_gpx( $gpx_path );
	if ( ! $pts ) {
		return null;
	}
	$total = end( $pts )['km'];
	$tz    = wp_timezone();

	// Höhenmeter mit 3-m-Schwelle gegen GPS-Rauschen
	$gain = 0.0;
	$ref  = $pts[0]['ele'];
	foreach ( $pts as $p ) {
		if ( $p['ele'] - $ref > 3 ) {
			$gain += $p['ele'] - $ref;
			$ref   = $p['ele'];
		} elseif ( $ref - $p['ele'] > 3 ) {
			$ref = $p['ele'];
		}
	}
	$stats = array( 'km' => round( $total, 1 ), 'hm' => (int) round( $gain ) );
	$first = $pts[0]['time'];
	$last  = end( $pts )['time'];
	if ( $first && $last ) {
		$mins           = (int) floor( ( $last - $first ) / 60 );
		$stats['dauer'] = sprintf( '%d:%02d', intdiv( $mins, 60 ), $mins % 60 );
	}

	$photos  = array();
	$missing = array();
	foreach ( $image_ids as $i => $id ) {
		list( $time, $pos ) = tourspur_fotospur_photo_info( $id );
		$best               = null;
		if ( $pos ) {
			$d = INF;
			foreach ( $pts as $p ) {
				$dd = tourspur_fotospur_km( $pos[0], $pos[1], $p['lat'], $p['lon'] );
				if ( $dd < $d ) {
					$d    = $dd;
					$best = $p;
				}
			}
		} elseif ( $time && $first ) {
			$d = INF;
			foreach ( $pts as $p ) {
				$dd = abs( $p['time'] - $time );
				if ( $dd < $d ) {
					$d    = $dd;
					$best = $p;
				}
			}
		}
		if ( ! $best ) {
			$missing[] = $id;
			continue;
		}
		$src   = wp_get_attachment_image_url( $id, 'large' );
		$title = wp_get_attachment_caption( $id );
		if ( ! $title ) {
			$title = get_the_title( $id );
		}
		$photos[] = array(
			'src'   => $src,
			'alt'   => get_post_meta( $id, '_wp_attachment_image_alt', true ) ?: $title,
			'title' => $title,
			'time'  => $best['time'] ? wp_date( 'H:i', $best['time'], $tz ) : '',
			'km'    => round( $best['km'], 2 ),
		);
	}

	// Fotos ohne Zeit und Ort gleichmäßig in der Reihenfolge der Auswahl verteilen
	$n = count( $missing );
	foreach ( $missing as $j => $id ) {
		$title    = wp_get_attachment_caption( $id ) ?: get_the_title( $id );
		$photos[] = array(
			'src'   => wp_get_attachment_image_url( $id, 'large' ),
			'alt'   => $title,
			'title' => $title,
			'time'  => '',
			'km'    => round( $total * ( $j + 1 ) / ( $n + 1 ), 2 ),
		);
	}
	usort(
		$photos,
		function ( $a, $b ) {
			return $a['km'] <=> $b['km'];
		}
	);

	// Strecke gleichmäßig auf höchstens 400 Punkte ausdünnen
	$track = array();
	$step  = $total / 399;
	$next  = 0.0;
	foreach ( $pts as $k => $p ) {
		if ( $p['km'] >= $next || $k === count( $pts ) - 1 ) {
			$track[] = array( round( $p['lat'], 5 ), round( $p['lon'], 5 ), round( $p['ele'], 1 ), round( $p['km'], 3 ) );
			$next   += $step;
		}
	}

	$data = array(
		'name'    => $name,
		'stats'   => $stats,
		'track'   => $track,
		'photos'  => $photos,
		'ungenau' => $n,
	);
	set_transient( $key, $data, WEEK_IN_SECONDS );
	return $data;
}

/**
 * Ausgabe des Blocks.
 */
function tourspur_fotospur_render( $attrs ) {
	$gpx_id    = (int) ( $attrs['gpxId'] ?? 0 );
	$image_ids = array_values( array_filter( array_map( 'intval', (array) ( $attrs['imageIds'] ?? array() ) ) ) );
	$wrapper   = get_block_wrapper_attributes( array( 'class' => 'fotospur-block' ) );

	if ( ! $gpx_id ) {
		return current_user_can( 'edit_posts' )
			? '<div ' . $wrapper . '><p class="fotospur-hinweis">Fotospur: Bitte eine GPX-Datei auswählen.</p></div>'
			: '';
	}
	$data = tourspur_fotospur_data( $gpx_id, $image_ids, (string) ( $attrs['name'] ?? '' ) );
	if ( ! $data ) {
		return current_user_can( 'edit_posts' )
			? '<div ' . $wrapper . '><p class="fotospur-hinweis">Fotospur: Die GPX-Datei enthält keine Strecke.</p></div>'
			: '';
	}

	wp_enqueue_script( 'tourspur-fotospur' );

	$s     = $data['stats'];
	$cells = array(
		array( str_replace( '.', ',', (string) $s['km'] ), 'Kilometer' ),
	);
	if ( ! empty( $s['dauer'] ) ) {
		$cells[] = array( $s['dauer'], 'Stunden' );
	}
	$cells[] = array( (string) $s['hm'], 'Höhenmeter' );
	$cells[] = array( (string) count( $data['photos'] ), 'Fotos' );

	$html = '<div ' . $wrapper . '><div class="fotospur-stats">';
	foreach ( $cells as $c ) {
		$html .= '<div>' . esc_html( $c[0] ) . '<small>' . esc_html( $c[1] ) . '</small></div>';
	}
	$html .= '</div>';

	$json  = wp_json_encode( $data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_AMP );
	$html .= '<div class="fotospur"><script type="application/json">' . $json . '</script></div>';

	if ( $data['ungenau'] && current_user_can( 'edit_posts' ) ) {
		$html .= '<p class="fotospur-hinweis">Nur für dich sichtbar: Bei ' . (int) $data['ungenau'] . ' Foto(s) fehlen Uhrzeit und Ort. Sie sind in der gewählten Reihenfolge auf der Strecke verteilt.</p>';
	}
	return $html . '</div>';
}
