FROM python:3.11.1-slim
RUN pip install psutil pyembedded
COPY raspi_monitor.py ./
CMD ["python","./raspi_monitor.py"]