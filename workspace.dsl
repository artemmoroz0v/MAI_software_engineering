workspace {
    name "File Storage System"
    !identifiers hierarchical

    model {

        user = Person "Пользователь" "Человек, который взаимодействует с системой для управления файлами и папками."

        externalSystem = softwareSystem "Внешняя система" "Система, которая интегрируется с хранилищем файлов."

        fileStorage = softwareSystem "Система хранения файлов" {
            -> externalSystem "Обмен данными"

            apiGateway = container "API Gateway" {
                technology "Python"
                tags "entry-point"
            }

            userService = container "Пользовательский сервис" {
                technology "Python"
                tags "user-management"
            }

            fileService = container "Файловый сервис" {
                technology "Python"
                tags "file-management"
            }

            folderService = container "Сервис папок" {
                technology "Python"
                tags "folder-management"
            }

            notificationService = container "Сервис уведомлений" {
                technology "Python"
                tags "notifications"
            }

            userDatabase = container "База данных пользователей" {
                technology "PostgreSQL"
                tags "storage"
            }

            fileStorageBucket = container "Хранилище файлов" {
                technology "AWS S3"
                tags "storage"
            }
        }

        user -> fileStorage.apiGateway "HTTP/HTTPS"
        externalSystem -> fileStorage.apiGateway "HTTP/HTTPS"

        fileStorage.apiGateway -> fileStorage.userService "HTTP/HTTPS"
        fileStorage.apiGateway -> fileStorage.fileService "HTTP/HTTPS"
        fileStorage.apiGateway -> fileStorage.folderService "HTTP/HTTPS"
        fileStorage.apiGateway -> fileStorage.notificationService "HTTP/HTTPS"

        fileStorage.userService -> fileStorage.userDatabase "CRUD операции"
        fileStorage.fileService -> fileStorage.fileStorageBucket "Загрузка/удаление файлов"
        fileStorage.folderService -> fileStorage.fileStorageBucket "Управление папками"

        fileStorage.notificationService -> user "Отправка уведомлений" "Email/SMS"

        deploymentEnvironment "PROD" {
            deploymentNode "DMZ" {
                deploymentNode "web-app.filestorage.ru" {
                    containerInstance fileStorage.apiGateway
                }
            }

            deploymentNode "PROTECTED" {
                deploymentNode "k8.namespace" {
                    lb = infrastructureNode "LoadBalancer"

                    pod1 = deploymentNode "pod1" {
                        us = containerInstance fileStorage.userService
                        instances 5
                    }
                    pod2 = deploymentNode "pod2" {
                        fs = containerInstance fileStorage.fileService
                        instances 3
                    }
                    pod3 = deploymentNode "pod3" {
                        ud = containerInstance fileStorage.userDatabase
                        fb = containerInstance fileStorage.fileStorageBucket
                    }
                    pod4 = deploymentNode "pod4" {
                        ns = containerInstance fileStorage.notificationService
                        fls = containerInstance fileStorage.folderService
                    }

                    lb -> pod1.us "Send requests"
                }
            }
        }
    }

    views {

        themes default

        systemContext fileStorage "context" {
            include *
            autoLayout lr
        }

        container fileStorage "c2" {
            include *
            autoLayout
        }

        deployment * "PROD" {
            include *
            autoLayout
        }

        dynamic fileStorage "Create_New_User" "Описывает процесс создания нового пользователя." {
            autoLayout lr
            user -> fileStorage.apiGateway "POST /users"
            fileStorage.apiGateway -> fileStorage.userService "POST /createUser"
            fileStorage.userService -> fileStorage.userDatabase "INSERT INTO users"
        }

        dynamic fileStorage "Find_User_By_Login" "Описывает процесс поиска пользователя по логину." {
            autoLayout lr
            user -> fileStorage.apiGateway "GET /users?login={login}"
            fileStorage.apiGateway -> fileStorage.userService "GET /findUserByLogin"
            fileStorage.userService -> fileStorage.userDatabase "SELECT FROM users WHERE login = ?"
        }

        dynamic fileStorage "Find_User_By_Name_Mask" "Описывает процесс поиска пользователя по маске имени и фамилии." {
            autoLayout lr
            user -> fileStorage.apiGateway "GET /users?nameMask={mask}"
            fileStorage.apiGateway -> fileStorage.userService "GET /findUserByNameMask"
            fileStorage.userService -> fileStorage.userDatabase "SELECT FROM users WHERE name LIKE ?"
        }

        dynamic fileStorage "Create_New_Folder" "Описывает процесс создания новой папки." {
            autoLayout lr
            user -> fileStorage.apiGateway "POST /folders"
            fileStorage.apiGateway -> fileStorage.folderService "POST /createFolder"
            fileStorage.folderService -> fileStorage.fileStorageBucket "Create folder in S3"
        }

        dynamic fileStorage "Get_All_Folders" "Описывает процесс получения списка всех папок." {
            autoLayout lr
            user -> fileStorage.apiGateway "GET /folders"
            fileStorage.apiGateway -> fileStorage.folderService "GET /listFolders"
            fileStorage.folderService -> fileStorage.fileStorageBucket "List folders in S3"
        }

        dynamic fileStorage "Create_File_In_Folder" "Описывает процесс создания файла в папке." {
            autoLayout lr
            user -> fileStorage.apiGateway "POST /folders/{folderId}/files"
            fileStorage.apiGateway -> fileStorage.fileService "POST /uploadFileToFolder"
            fileStorage.fileService -> fileStorage.fileStorageBucket "Upload file to S3 folder"
        }

        dynamic fileStorage "Get_File_By_Name" "Описывает процесс получения файла по имени." {
            autoLayout lr
            user -> fileStorage.apiGateway "GET /files?name={fileName}"
            fileStorage.apiGateway -> fileStorage.fileService "GET /getFileByName"
            fileStorage.fileService -> fileStorage.fileStorageBucket "Retrieve file from S3"
        }

        dynamic fileStorage "Delete_File" "Описывает процесс удаления файла." {
            autoLayout lr
            user -> fileStorage.apiGateway "DELETE /files/{fileId}"
            fileStorage.apiGateway -> fileStorage.fileService "DELETE /deleteFile"
            fileStorage.fileService -> fileStorage.fileStorageBucket "Delete file from S3"
        }

        dynamic fileStorage "Delete_Folder" "Описывает процесс удаления папки." {
            autoLayout lr
            user -> fileStorage.apiGateway "DELETE /folders/{folderId}"
            fileStorage.apiGateway -> fileStorage.folderService "DELETE /deleteFolder"
            fileStorage.folderService -> fileStorage.fileStorageBucket "Delete folder from S3"
        }
    }
}