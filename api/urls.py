from django.urls import path
from .enhanced_views import EnhancedChatView, DocumentManagementView, ChatHistoryView

urlpatterns = [
    # Enhanced authenticated endpoints (main functionality)
    path('chat/', EnhancedChatView.as_view(), name='enhanced_chat'),
    path('documents/', DocumentManagementView.as_view(), name='documents'),
    path('documents/<str:document_id>/', DocumentManagementView.as_view(), name='document_detail'),
    path('chat-history/', ChatHistoryView.as_view(), name='chat_history'),
] 