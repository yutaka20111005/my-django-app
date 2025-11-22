from django.shortcuts import render
from django.http import HttpResponse


def home(request):
    """Home page view."""
    context = {
        'title': 'Welcome to My Django App',
        'message': 'This is a sample Django application deployed on AWS ECR!',
    }
    return render(request, 'pages/home.html', context)


def about(request):
    """About page view."""
    context = {
        'title': 'About',
        'message': 'This is a sample Django application for GitHub Actions + AWS ECR deployment.',
    }
    return render(request, 'pages/about.html', context)

