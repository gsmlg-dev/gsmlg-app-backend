#!/bin/bash

VER=${1:-1.0.0}

FILES=(
  apps/gsmlg_app/mix.exs
  apps/gsmlg_app_admin/mix.exs
  apps/gsmlg_app_admin_web/mix.exs
  apps/gsmlg_app_component/mix.exs
  apps/gsmlg_app_web/mix.exs
  mix.exs
)

for n in ${FILES[@]}
do
  echo $n
  sed -i "s;version: \"[^\"]\\+\";version: \"${VER}\";g" $n;
  sed -i "s;@version \"[^\"]\\+\";@version \"${VER}\";g" $n;
done
