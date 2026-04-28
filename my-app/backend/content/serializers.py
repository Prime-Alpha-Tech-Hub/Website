from rest_framework import serializers
from .models import (
    HeroSection, Section, Feature, Testimonial, CallToAction, SiteSettings,
    InvestorPageWhyCard, InvestorPageStrategy, InvestorPageQualification
)


class HeroSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeroSection
        fields = '__all__'


class SectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Section
        fields = '__all__'


class FeatureSerializer(serializers.ModelSerializer):
    class Meta:
        model = Feature
        fields = '__all__'


class TestimonialSerializer(serializers.ModelSerializer):
    class Meta:
        model = Testimonial
        fields = '__all__'


class CallToActionSerializer(serializers.ModelSerializer):
    class Meta:
        model = CallToAction
        fields = '__all__'


class SiteSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = SiteSettings
        fields = '__all__'


class InvestorPageWhyCardSerializer(serializers.ModelSerializer):
    class Meta:
        model = InvestorPageWhyCard
        fields = ['icon', 'title_en', 'description_en', 'title_fr', 'description_fr']


class InvestorPageStrategySerializer(serializers.ModelSerializer):
    class Meta:
        model = InvestorPageStrategy
        fields = ['code', 'name_en', 'name_fr', 'description_en', 'description_fr', 'page']


class InvestorPageQualificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = InvestorPageQualification
        fields = ['text_en', 'text_fr']
