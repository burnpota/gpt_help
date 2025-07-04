def binary_search_iter(arr, target):
    left, right = 0, len(arr) - 1
    
    while left <= right:
        mid = (left + right) // 2
        
        if arr[mid] == target:
            return mid  # 찾았을 경우 인덱스 반환
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
            
    return -1  # 찾지 못한 경우
