FROM python:3.14-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    AI_API_URL=http://127.0.0.1:8002 ALLOW_BASELINE_RETRAIN=false
WORKDIR /srv
COPY ["backendApiNutricare NEW/backendApiNutricare NEW/requirements.txt", "/srv/backend-requirements.txt"]
COPY deploy/requirements-ml.txt /srv/ml-requirements.txt
RUN pip install --no-cache-dir -r backend-requirements.txt -r ml-requirements.txt
COPY ["backendApiNutricare NEW/backendApiNutricare NEW/app", "/srv/backend/app"]
COPY Diet_Plan_AI_Complete_v3/*.py /srv/ml/
COPY Diet_Plan_AI_Complete_v3/models/ /srv/ml/models/
COPY Diet_Plan_AI_Complete_v3/final_pakistani_diabetic_meal_plans.csv /srv/ml/
COPY deploy/start.py /srv/start.py
RUN useradd --create-home appuser && chown -R appuser:appuser /srv
USER appuser
EXPOSE 10000
CMD ["python", "/srv/start.py"]
