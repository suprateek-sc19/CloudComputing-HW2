FROM python:3

WORKDIR /app

COPY . /app

ENV FLASK_ENV=development
ENV PORT=3000

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 3000

CMD ["flask", "run", "--host=0.0.0.0", "--port=3000"]