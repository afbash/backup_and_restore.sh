#!/bin/bash

# Variables globales
LOG_FILE="backup_restore.log"
EMAIL="usuario@example.com"
EXCLUIR_ARCHIVOS=""
FRECUENCIA_BACKUP=""

# Función para mostrar el menú
mostrar_menu() {
    echo "Menú de Opciones:"
    echo "a) Realizar backup"
    echo "b) Restaurar backup"
    echo "c) Guardar script con datos de backup"
    echo "d) Configurar exclusión de archivos/carpetas"
    echo "e) Configurar frecuencia de backups incrementales"
    echo "f) Salir"
    echo -n "Seleccione una opción: "
}

# Función para realizar backup incremental con rsync
realizar_backup() {
    # Solicitar datos al usuario
    read -p "Ingrese la IP del servidor de origen: " ip_origen
    read -p "Ingrese el usuario del servidor de origen: " user_origen
    read -sp "Ingrese la contraseña del servidor de origen: " pass_origen
    echo ""
    read -p "Ingrese la ruta del archivo o carpeta a respaldar: " ruta_origen
    read -p "Ingrese la IP del servidor de destino: " ip_destino
    read -p "Ingrese el usuario del servidor de destino: " user_destino
    read -sp "Ingrese la contraseña del servidor de destino: " pass_destino
    echo ""
    read -p "Ingrese la ruta de destino para el backup en el servidor de destino: " ruta_destino

    # Crear el nombre del backup con la fecha y hora actual
    nombre_backup="backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    # Llamar a rsync para realizar el backup
    if [[ "$ip_origen" == "$ip_destino" ]]; then
        # Si ambos son el mismo servidor, usar rsync sin SSH
        rsync -avz --delete "$ruta_origen" "$user_destino@$ip_destino:$ruta_destino/$nombre_backup" &>> $LOG_FILE
    else
        # Si son diferentes, usar SSH
        rsync -avz --delete "$user_origen@$ip_origen:$ruta_origen" "$user_destino@$ip_destino:$ruta_destino/$nombre_backup" &>> $LOG_FILE
    fi

    # Comprobar si rsync tuvo éxito
    if [[ $? -eq 0 ]]; then
        echo "Backup realizado con éxito." | tee -a $LOG_FILE
    else
        echo "Error al realizar el backup" | tee -a $LOG_FILE
    fi
}


# Función para restaurar backup
restaurar_backup() {
    read -p "Ingrese la IP del servidor de origen del backup: " ip_origen
    validar_entrada "$ip_origen" || return 1
    read -p "Ingrese el usuario del servidor de origen del backup: " user_origen
    validar_entrada "$user_origen" || return 1
    read -sp "Ingrese la contraseña del servidor de origen: " pass_origen
    echo
    read -p "Ingrese la ruta del backup en el servidor de origen: " ruta_origen
    validar_entrada "$ruta_origen" || return 1
    read -p "Ingrese la IP del servidor de destino: " ip_destino
    validar_entrada "$ip_destino" || return 1
    read -p "Ingrese el usuario del servidor de destino: " user_destino
    validar_entrada "$user_destino" || return 1
    read -sp "Ingrese la contraseña del servidor de destino: " pass_destino
    echo
    read -p "Ingrese la ruta de destino para restaurar: " ruta_destino
    validar_entrada "$ruta_destino" || return 1

    # Listar backups disponibles
    echo "Buscando backups disponibles en $ruta_origen..."
    ssh "$user_origen@$ip_origen" "ls -1 $ruta_origen" &>> $LOG_FILE
    ssh "$user_origen@$ip_origen" "ls -1 $ruta_origen"

    read -p "Seleccione el archivo de backup a restaurar: " backup_seleccionado
    rsync -avz "$user_origen@$ip_origen:$ruta_origen/$backup_seleccionado" "$user_destino@$ip_destino:$ruta_destino" &>> $LOG_FILE

    if [[ $? -eq 0 ]]; then
        echo "Restauración exitosa de $backup_seleccionado"
        echo "Restauración exitosa de $backup_seleccionado" | mail -s "Restauración exitosa" $EMAIL
    else
        echo "Error en la restauración"
        echo "Error en la restauración" | mail -s "Error en restauración" $EMAIL
    fi
}

# Función para guardar el script con los datos de backup
guardar_script() {
    read -p "Ingrese el nombre del script a guardar (sin extensión): " nombre_script
    validar_entrada "$nombre_script" || return 1
    read -p "Ingrese la ruta donde desea guardar el script: " ruta_guardado
    validar_entrada "$ruta_guardado" || return 1

    cat <<EOF > "$ruta_guardado/$nombre_script.sh"
#!/bin/bash
# Script autogenerado para realizar backups
LOG_FILE="backup_restore.log"
rsync -avz --delete --exclude="$EXCLUIR_ARCHIVOS" "$user_origen@$ip_origen:$ruta_origen" "$user_destino@$ip_destino:$ruta_destino/$nombre_backup" &>> \$LOG_FILE
EOF

    chmod +x "$ruta_guardado/$nombre_script.sh"
    echo "Script guardado exitosamente en $ruta_guardado/$nombre_script.sh"
}

# Función para configurar exclusión de archivos/carpetas
configurar_exclusion() {
    read -p "Ingrese los archivos o carpetas a excluir del backup (separados por comas): " EXCLUIR_ARCHIVOS
    validar_entrada "$EXCLUIR_ARCHIVOS" || return 1
    echo "Archivos o carpetas excluidos: $EXCLUIR_ARCHIVOS"
}

# Función para configurar la frecuencia de backup
configurar_frecuencia_backup() {
    read -p "Ingrese la frecuencia del backup en minutos: " FRECUENCIA_BACKUP
    validar_entrada "$FRECUENCIA_BACKUP" || return 1

    echo "Backup configurado para ejecutarse cada $FRECUENCIA_BACKUP minutos."

    (crontab -l ; echo "*/$FRECUENCIA_BACKUP * * * * /ruta/del/script.sh") | crontab -
}

# Función para validar entradas del usuario
validar_entrada() {
    if [[ -z "$1" ]]; then
        echo "Error: Entrada vacía. Intente de nuevo."
        return 1
    fi
    return 0
}

# Función principal
main() {
    while true; do
        mostrar_menu
        read opcion
        case $opcion in
            a)
                realizar_backup
                ;;
            b)
                restaurar_backup
                ;;
            c)
                guardar_script
                ;;
            d)
                configurar_exclusion
                ;;
            e)
                configurar_frecuencia_backup
                ;;
            f)
                echo "Saliendo..."
                exit 0
                ;;
            *)
                echo "Opción no válida"
                ;;
        esac
    done
}

# Ejecutar función principal
main

