from django.db import models


class InvestorPageWhyCard(models.Model):
    order = models.PositiveIntegerField(default=0)
    title_en = models.CharField(max_length=150)
    title_fr = models.CharField(max_length=150)
    description_en = models.TextField()
    description_fr = models.TextField()
    icon = models.CharField(max_length=1, default="◆")

    def __str__(self):
        return self.title_en

    class Meta:
        ordering = ['order']
        verbose_name = 'Investor Page - Why Card'


class InvestorPageStrategy(models.Model):
    order = models.PositiveIntegerField(default=0)
    name_en = models.CharField(max_length=150)
    name_fr = models.CharField(max_length=150)
    code = models.CharField(max_length=10)
    description_en = models.TextField()
    description_fr = models.TextField()
    page = models.CharField(max_length=50)

    def __str__(self):
        return f"{self.code}: {self.name_en}"

    class Meta:
        ordering = ['order']
        verbose_name = 'Investor Page - Strategy'


class InvestorPageQualification(models.Model):
    order = models.PositiveIntegerField(default=0)
    text_en = models.TextField()
    text_fr = models.TextField()

    def __str__(self):
        return f"Qualification {self.order}"

    class Meta:
        ordering = ['order']
        verbose_name = 'Investor Page - Qualification'


class HeroSection(models.Model):
    title = models.CharField(max_length=200)
    subtitle = models.TextField()
    cta_text = models.CharField(max_length=100, default='Learn More')
    cta_link = models.URLField(default='/')
    image_url = models.URLField(blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title

    class Meta:
        verbose_name = 'Hero Section'
        verbose_name_plural = 'Hero Section'


class Section(models.Model):
    title = models.CharField(max_length=200)
    slug = models.SlugField(unique=True)
    content = models.TextField()
    order = models.PositiveIntegerField(default=0)
    published = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['order']


class Feature(models.Model):
    title = models.CharField(max_length=150)
    description = models.TextField()
    icon_url = models.URLField(blank=True)
    order = models.PositiveIntegerField(default=0)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['order']


class Testimonial(models.Model):
    name = models.CharField(max_length=150)
    role = models.CharField(max_length=150)
    message = models.TextField()
    avatar_url = models.URLField(blank=True)
    order = models.PositiveIntegerField(default=0)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['order']


class CallToAction(models.Model):
    title = models.CharField(max_length=200)
    text = models.TextField()
    button_text = models.CharField(max_length=100)
    button_url = models.URLField()
    position = models.CharField(
        max_length=20,
        choices=[('top', 'Top'), ('middle', 'Middle'), ('bottom', 'Bottom')],
        default='bottom'
    )

    def __str__(self):
        return self.title

    class Meta:
        verbose_name = 'Call to Action'
        verbose_name_plural = 'Calls to Action'


class SiteSettings(models.Model):
    site_name = models.CharField(max_length=200, default='Prime Alpha Tech Hub')
    tagline = models.CharField(max_length=300, blank=True)
    logo_url = models.URLField(blank=True)
    favicon_url = models.URLField(blank=True)
    contact_email = models.EmailField()
    phone = models.CharField(max_length=20, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.site_name

    class Meta:
        verbose_name_plural = 'Site Settings'
