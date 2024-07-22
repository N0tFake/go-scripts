# Golang Scripst Bash

Repository with bash scripts for golang

## 1. Create Project With Gorm, Gin and Viper

### Script
```
create_go_project.sh
```

### Usage
```sh
./create_go_project.sh <project_name> <directory> [mysql|postgres|sqlite]
```

- `<project_name>`: Nome do novo projeto Go.
- `<directory>`: Diretório onde o projeto será criado.
- `[mysql|postgres|sqlite]`: (Opcional) Tipo de banco de dados. O padrão é `sqlite`.