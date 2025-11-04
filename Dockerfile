FROM python:3.10
WORKDIR /app
COPY app/ /app/
RUN pip install -r requirements.txt
EXPOSE 8081
CMD ["python", "app.py"]

