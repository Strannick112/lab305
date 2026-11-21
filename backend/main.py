import os
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBasic, HTTPBasicCredentials

app = FastAPI()
security = HTTPBasic()


# Определяем базовую директорию проекта относительно файла main.py
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# В релизе используйте хэшированиые переменные!
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "admin"

# Функция проверки пароля для HTTPS Basic Auth
def authenticate_admin(credentials: HTTPBasicCredentials = Depends(security)):
    correct_username = credentials.username == ADMIN_USERNAME
    correct_password = credentials.password == ADMIN_PASSWORD
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный логин или пароль",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

# Path к папке frontend и её подпапкам
FRONTEND_DIR = os.path.join(BASE_DIR, "frontend")
ASSETS_DIR = os.path.join(FRONTEND_DIR, "assets")
PAGES_DIR = os.path.join(FRONTEND_DIR, "pages")

# Монтируем папку assets для раздачи статики (css, js, images) по адресу /assets
app.mount("/assets", StaticFiles(directory=ASSETS_DIR), name="assets")

# Маршрут для отдачи главной страницы index.html
@app.get("/")
async def read_index():
    return FileResponse(os.path.join(PAGES_DIR, "index.html"))

# Защищенный маршрут для админки (сначала проверяет пароль)
@app.get("/admin")
def get_admin_page(username: str = Depends(authenticate_admin)):
    # Путь к файлу из папки frontend относительно папки backend
    admin_page_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../frontend/pages/admin.html"))
    return FileResponse(admin_page_path)