#!/bin/bash

# format: --plugin "pluginName:uriPrefix:configFile"
stack build && stack exec sgHomePage-exe -- \
	--css-config demo/attributes_config.yaml \
	--plugin projDB:projDB:demo/projDB.yaml \
	--plugin website:content:demo/website_cfg.yaml \
	$@
