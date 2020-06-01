# The Dockerfile defines the image's environment
# Import Python runtime and set up working directory
FROM python:3
WORKDIR /app
ADD . /app

# Install any necessary dependencies
RUN pip install -r requirements.txt

# Open port 80 for serving the webpage
EXPOSE 80

# Run main.py when the container launches
CMD ["python", "main.py"]
