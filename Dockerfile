# Getting lambda python version
FROM public.ecr.aws/lambda/python:3.11

# Copying requirements to the Lambda work directory
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Installing libraries into the container system
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copying the main lambda program file
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Directing runtime to the handler
CMD ["lambda_function.lambda_handler"]

