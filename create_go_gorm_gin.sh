#!/bin/bash

echo "Creating new Go project with GORM, Gin and Viper"

# Check if the project name is provided
if [ $# -lt 1 ]; then
	echo "Usage: $0 <directory> <project_name> [mysql|postgres|sqlite]"
	exit 1
fi

# Define the directory where the project will be created
directory=$1

# Define name of the project
project_name=$2

# Define the database type
db_type=${3:-sqlite}

# Create the directory for the project
mkdir -p $directory
cd $directory

# Create a new directory for the project
# mkdir $project_name
# cd $project_name

# Initialize a new Go module
go mod init $project_name

# Install dependencies
go get -u github.com/gin-gonic/gin
go get -u github.com/spf13/viper
go get -u github.com/joho/godotenv

# Install GORM and the database driver
case $db_type in
    mysql)
        go get -u gorm.io/driver/mysql
        db_import="gorm.io/driver/mysql"
        db_dsn="%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local"
        cat <<EOL > app.env
DB_DRIVER=mysql
DB_HOST=localhost
DB_PORT=3306
DB_USER=user
DB_PASSWORD=password
DB_NAME=dbname
EOL
        ;;
    postgres)
        go get -u gorm.io/driver/postgres
        db_import="gorm.io/driver/postgres"
        db_dsn="postgres://%s:%s@%s:%s/%s?sslmode=disable"
        cat <<EOL > app.env
DB_DRIVER=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USER=user
DB_PASSWORD=password
DB_NAME=dbname
EOL
        ;;
    sqlite)
        go get -u gorm.io/driver/sqlite
        db_import="gorm.io/driver/sqlite"
        db_dsn="%s"
        cat <<EOL > app.env
DB_DRIVER=sqlite
DB_DSN=test.db
EOL
        ;;
    *)
        echo "Unsupported database type: $db_type"
        exit 1
        ;;
esac

# Install GORM
go get -u gorm.io/gorm

# Create directories
mkdir -p config/initializations
mkdir -p service
mkdir -p cmd/app/routes

# Create the loadEnv.go file
cat <<EOL > config/initializations/loadEnv.go
package initializers

import (
	"github.com/spf13/viper"
)

type Config struct {
	DBDriver   string \`mapstructure:"DB_DRIVER"\`
	DBHost     string \`mapstructure:"DB_HOST"\`
	DBUser     string \`mapstructure:"DB_USER"\`
	DBPassword string \`mapstructure:"DB_PASSWORD"\`
	DBName     string \`mapstructure:"DB_NAME"\`
	DBPort     string \`mapstructure:"DB_PORT"\`
	DBDSN      string \`mapstructure:"DB_DSN"\`
}

func LoadConfig(path string) (config Config, err error) {
	viper.AddConfigPath(path)
	viper.SetConfigType("env")
	viper.SetConfigName("app")
	viper.AutomaticEnv()

	err = viper.ReadInConfig()
	if err != nil {
		return
	}

	err = viper.Unmarshal(&config)
	return
}
EOL

# Create the database.go file
cat <<EOL > service/database.go
package service

import (
	"fmt"
	"log"

	initializers "$project_name/config/initializations"
	"gorm.io/gorm"
	"$db_import"
)

var DB *gorm.DB

type Log struct {
	ID      uint   \`gorm:"primaryKey"\`
	Data    string \`gorm:"type:date"\`
	Message string
}

func ConnectDatabase(config *initializers.Config) {
	fmt.Println("> Connecting database...")

	var dsn string
	if config.DBDriver == "sqlite" {
		dsn = config.DBDSN
	} else {
		dsn = fmt.Sprintf("$db_dsn",
			config.DBUser,
			config.DBPassword,
			config.DBHost,
			config.DBPort,
			config.DBName,
		)
	}

	db, err := gorm.Open($db_type.Open(dsn), &gorm.Config{})
	if err != nil {
		panic("Error connecting database")
	}

	log.Println("> Connected to the database")

	err = db.AutoMigrate(&Log{})
	if err != nil {
		panic("Error migrating")
	}

	DB = db
}
EOL

# Create the routes.go file
cat <<EOL > cmd/app/routes/routes.go
package routes

import (
	"github.com/gin-gonic/gin"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()

	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})

	return r
}
EOL

# Create the main.go file
cat <<EOL > cmd/app/main.go
package main

import (
	"$project_name/cmd/app/routes"
	initializers "$project_name/config/initializations"
	"$project_name/service"
	"log"
)

func main() {
	config, err := initializers.LoadConfig(".")
	if err != nil {
		log.Fatalf("Error loading environment variables: %v", err)
	}

	service.ConnectDatabase(&config)

	r := routes.SetupRouter()

	if err := r.Run(); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}
EOL

echo "Project $project_name created successfully with $db_type database!"
